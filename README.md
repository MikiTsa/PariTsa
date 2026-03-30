# PariTsa — Expenses Tracker

A personal finance tracking app built with Flutter and Firebase. Log your expenses, incomes, and savings — all synced in real-time across devices.

---

## Features

- **Expense tracking** — log what you spend, with custom or default categories
- **Income tracking** — record salary, gifts, investments, and other income sources
- **Savings tracking** — keep tabs on what you're setting aside
- **Live balance** — current balance (incomes − expenses − savings) updates instantly
- **Transaction details** — each entry supports a title, amount, date, category, optional note, and optional tag
- **Tags** — attach a free-form label to any transaction (e.g. "Vacation 2025", "Side project") for cross-category grouping
- **Edit & delete** — tap any transaction to view details, edit it, or remove it
- **Custom categories** — add, reorder, and delete categories per transaction type (expenses / incomes / savings)
- **History** — unified chronological feed of all transactions across all types
- **Analytics** — summary cards, charts, and filters to understand spending and income patterns
- **Sidebar (drawer)** — quick access to Categories, Profile, History, Analytics, and Settings
- **Profile** — view and edit your display name; see email and member-since date
- **Settings** — choose theme (System / Light / Dark), currency (20+ options, default EUR), date format, and default tab
- **Dark mode** — full dark theme with a deep navy palette, respects system preference
- **Google Wallet auto-capture** — Android only: detects Google Pay notifications and offers to log the payment as an expense automatically
- **Biometric lock** — optional fingerprint / face unlock; auto-locks after 30 seconds in background
- **Google Sign-In** — sign in with Google or register with email and password
- **Secure data** — every user's data is private and protected by Firestore security rules

---

## Tech stack

| | |
|---|---|
| Framework | Flutter (Dart 3.7+, Material 3) |
| Authentication | Firebase Auth — email/password & Google Sign-In |
| Database | Cloud Firestore (real-time) |
| Local auth | `local_auth` (biometric) |
| Notifications | `flutter_local_notifications` |
| Persistence | `shared_preferences` (settings) |
| Platforms | Android, iOS, macOS, Windows, Web |

---

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed
- A Firebase project with **Authentication** and **Firestore** enabled
- [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) installed

### Setup

1. Clone the repository
   ```bash
   git clone https://github.com/MikiTsa/PariTsa.git
   cd PariTsa
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Connect your Firebase project
   ```bash
   flutterfire configure
   ```
   This generates `lib/firebase_options.dart` and `android/app/google-services.json` (not committed to the repo).

4. Deploy the Firestore security rules
   ```bash
   firebase deploy --only firestore:rules --project expenses-tracker-3fd49
   ```

5. Run the app
   ```bash
   flutter run
   ```

> **Android — Google Wallet capture:** After installing, go to Android Settings → Apps → Special App Access → Notification Access and enable the app to allow auto-capture of Google Pay notifications.

---

## Project structure

```
lib/
├── main.dart                          # Entry point & app theme
├── theme/
│   ├── app_colors.dart                # Color palette constants
│   ├── app_theme.dart                 # ThemeData (light + dark)
│   └── theme_extensions.dart          # BuildContext color helpers
├── models/
│   ├── transaction.dart               # Transaction model & type enum
│   └── user_model.dart                # User model
├── providers/
│   └── app_settings.dart              # AppSettings ChangeNotifier (theme, currency, etc.)
├── services/
│   ├── auth_service.dart              # Authentication logic
│   ├── firebase_service.dart          # Firestore read/write operations
│   ├── settings_service.dart          # shared_preferences persistence
│   ├── biometric_service.dart         # local_auth wrapper
│   ├── wallet_notification_service.dart  # Google Wallet EventChannel (Android)
│   └── local_notification_service.dart   # System notification wrapper
├── screens/
│   ├── auth/                          # Login, register, forgot password, auth wrapper
│   ├── home_screen.dart               # Main tab host + wallet stream subscriber
│   ├── biometric_lock_screen.dart     # Biometric gate shown on resume
│   ├── expenses_screen.dart
│   ├── incomes_screen.dart
│   ├── savings_screen.dart
│   └── sidebar/
│       ├── categories_screen.dart     # Manage custom categories
│       ├── profile_screen.dart        # Display name, email, member since
│       ├── history_screen.dart        # Unified chronological transaction feed
│       ├── analytics_screen.dart      # Charts, summary cards, filters
│       └── settings_screen.dart       # Theme, currency, date format, default tab, biometric
└── widgets/
    ├── app_drawer.dart                # Sidebar drawer
    ├── balance_box.dart               # Floating balance indicator
    ├── transaction_form.dart          # Add / edit form
    └── transaction_list.dart          # Grouped transaction list
```
