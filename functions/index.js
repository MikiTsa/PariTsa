const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

/**
 * Fires when a new shared transaction is created.
 * Sends an FCM notification to every member of the tracker except the sender.
 */
exports.onSharedTransactionCreated = onDocumentCreated(
  'sharedTrackers/{trackerId}/transactions/{txId}',
  async (event) => {
    const { trackerId } = event.params;
    const tx = event.data.data();

    const db = getFirestore();

    // Read the tracker to get members list and tracker name
    const trackerDoc = await db
      .collection('sharedTrackers')
      .doc(trackerId)
      .get();

    if (!trackerDoc.exists) return;

    const tracker = trackerDoc.data();
    const members = tracker.members || [];
    const trackerName = tracker.name || 'Shared Tracker';

    // Identify the sender — the member whose split is in the transaction
    // We use createdByUid if present, otherwise fall back to finding who
    // has the largest split (best-effort heuristic for older transactions).
    const splits = tx.splits || [];
    const senderUid = tx.createdByUid || (splits.length > 0 ? splits[0].uid : null);

    // Collect FCM tokens from every member except the sender
    const recipientUids = members
      .map((m) => m.uid)
      .filter((uid) => uid !== senderUid);

    if (recipientUids.length === 0) return;

    // Find sender's display name for the notification body
    const senderMember = members.find((m) => m.uid === senderUid);
    const senderName = senderMember ? senderMember.displayName : 'Someone';

    // Fetch FCM tokens for all recipients in parallel
    const tokenSnapshots = await Promise.all(
      recipientUids.map((uid) =>
        db.collection('users').doc(uid).collection('fcmTokens').get()
      )
    );

    const tokens = [];
    for (const snap of tokenSnapshots) {
      for (const doc of snap.docs) {
        const token = doc.data().token;
        if (token) tokens.push(token);
      }
    }

    if (tokens.length === 0) return;

    // Send one multicast message to all recipient tokens
    const message = {
      notification: {
        title: trackerName,
        body: `${senderName} added an expense`,
      },
      data: {
        trackerId,
      },
      tokens,
    };

    const response = await getMessaging().sendEachForMulticast(message);

    // Clean up any tokens that are no longer valid
    const staleTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const code = resp.error?.code;
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
        ) {
          staleTokens.push(tokens[idx]);
        }
      }
    });

    if (staleTokens.length > 0) {
      // Delete stale tokens from all users' fcmTokens subcollections
      const deleteOps = [];
      for (const uid of recipientUids) {
        const snap = await db
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .where('token', 'in', staleTokens)
          .get();
        for (const doc of snap.docs) {
          deleteOps.push(doc.ref.delete());
        }
      }
      await Promise.all(deleteOps);
    }
  }
);
