# Expenses Tracker

A personal finance tracking app built with Flutter and Firebase. Log your expenses, incomes, and savings — all synced in real-time across devices.

---

## Features

- **Expense tracking** — log what you spend, with categories like Food, Transport, Shopping, and more
- **Income tracking** — record your salary, gifts, investments, and other income sources
- **Savings tracking** — keep tabs on what you're setting aside (Emergency Fund, Vacation, Education, etc.)
- **Live balance** — your current balance (incomes minus expenses minus savings) updates instantly
- **Transaction details** — each entry supports a title, amount, date, category, and optional note
- **Edit & delete** — tap any transaction to view details, edit it, or remove it
- **Google Sign-In** — sign in with your Google account or register with email and password
- **Secure data** — every user's data is private and protected by Firestore security rules

---

## Tech stack

| | |
|---|---|
| Framework | Flutter (Dart 3.7+, Material 3) |
| Authentication | Firebase Auth — email/password & Google Sign-In |
| Database | Cloud Firestore (real-time) |
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
   git clone https://github.com/your-username/expenses-tracker.git
   cd expenses-tracker
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
   firebase deploy --only firestore:rules
   ```

5. Run the app
   ```bash
   flutter run
   ```

---

## Project structure

```
lib/
├── main.dart                    # Entry point & app theme
├── theme/
│   └── app_colors.dart          # Color palette constants
├── models/
│   ├── transaction.dart         # Transaction model & type enum
│   └── user_model.dart          # User model
├── services/
│   ├── auth_service.dart        # Authentication logic
│   └── firebase_service.dart    # Firestore read/write operations
├── screens/
│   ├── auth/                    # Login, register, forgot password
│   ├── home_screen.dart         # Main tab host
│   ├── expenses_screen.dart
│   ├── incomes_screen.dart
│   └── savings_screen.dart
└── widgets/
    ├── balance_box.dart         # Floating balance indicator
    ├── transaction_form.dart    # Add / edit form
    └── transaction_list.dart    # Grouped transaction list
```
