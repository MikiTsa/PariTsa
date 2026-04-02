import 'dart:async';

import 'package:expenses_tracker/models/shared_tracker.dart';
import 'package:expenses_tracker/screens/sidebar/shared_tracker_detail_screen.dart';
import 'package:expenses_tracker/services/firebase_service.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:expenses_tracker/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SharedTrackingScreen extends StatefulWidget {
  const SharedTrackingScreen({super.key});

  @override
  State<SharedTrackingScreen> createState() => _SharedTrackingScreenState();
}

class _SharedTrackingScreenState extends State<SharedTrackingScreen> {
  final _service = FirebaseService();
  List<SharedTracker> _trackers = [];
  bool _loading = true;
  StreamSubscription<List<SharedTracker>>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _service.getSharedTrackersStream().listen((trackers) {
      if (mounted) {
        setState(() {
          _trackers = trackers;
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _openTracker(SharedTracker tracker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SharedTrackerDetailScreen(trackerId: tracker.id),
      ),
    );
  }

  void _showCreateDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create shared tracker'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Apartment, Vacation 2025',
            labelText: 'Tracker name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final tracker = await _service.createSharedTracker(name);
                if (mounted) _openTracker(tracker);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog() {
    final ctrl = TextEditingController();
    bool joining = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Join shared tracker'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ask the tracker owner for the 6-character invite code.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Invite code',
                  hintText: 'e.g. AB12CD',
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: joining ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: joining
                  ? null
                  : () async {
                      final code = ctrl.text.trim();
                      if (code.length != 6) return;
                      setDlgState(() => joining = true);
                      // Capture messenger before the async gap
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final tracker =
                            await _service.joinSharedTrackerByCode(code);
                        if (!context.mounted) return;
                        Navigator.pop(ctx);
                        _openTracker(tracker);
                      } catch (e) {
                        setDlgState(() => joining = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: joining
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Tracking'),
        backgroundColor: context.cAppBar,
        foregroundColor: context.cPrimaryText,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trackers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _trackers.length,
                  itemBuilder: (ctx, i) => _TrackerCard(
                    tracker: _trackers[i],
                    onTap: () => _openTracker(_trackers[i]),
                  ),
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showJoinDialog,
                  icon: const Icon(Icons.input_outlined, size: 18),
                  label: const Text('Join tracker'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _showCreateDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create tracker'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 72,
              color: AppColors.mutedText.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No shared trackers',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.cPrimaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a tracker and invite friends or family to split expenses together.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.cMutedText, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackerCard extends StatelessWidget {
  final SharedTracker tracker;
  final VoidCallback onTap;

  const _TrackerCard({required this.tracker, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: const Icon(Icons.people_outline, color: AppColors.primary),
        ),
        title: Text(
          tracker.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.cPrimaryText,
          ),
        ),
        subtitle: Text(
          '${tracker.members.length} member${tracker.members.length == 1 ? '' : 's'} · '
          'Created ${DateFormat.yMMMd().format(tracker.createdAt)}',
          style: TextStyle(color: context.cMutedText, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Member colour dots
            ...tracker.members.take(4).map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: m.color,
                    ),
                  ),
                ),
            if (tracker.members.length > 4)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: AppColors.mutedText.withValues(alpha: 0.4),
                  child: Text(
                    '+${tracker.members.length - 4}',
                    style: const TextStyle(
                        fontSize: 8, color: Colors.white),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: context.cMutedText),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
