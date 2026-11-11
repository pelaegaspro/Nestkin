# Nestkin — Family & Household Coordination

A Flutter application for organising everyday family life: shared tasks, household communication, calendars, shopping lists, expenses and reminders.

> **Repository status:** Active application code / portfolio project. The presence of a feature screen or service does not imply that every integration is production-ready.

## What it covers

- **Household workspace:** Members, invitations and role-aware household views
- **Planning:** Task assignments, weekly planning and shared calendar flows
- **Everyday coordination:** Shopping lists, shared notes and household expenses
- **Communication:** Household chat and push-notification handling
- **Care & safety workflows:** Medicine reminders, emergency/SOS history and location-related screens

These are features and workflows represented in the repository; availability depends on configuration and the specific build.

## Engineering highlights

- Flutter and Dart mobile UI with modular `screens/`, `services/`, `models/` and `widgets/` directories
- Firebase Authentication, Cloud Firestore, Cloud Storage and Firebase Cloud Messaging
- Firestore offline persistence, asynchronous data access and notification routing
- Google Maps / location integration and calendar-related service code

## Stack

`Flutter` · `Dart` · `Firebase Auth` · `Cloud Firestore` · `FCM` · `Firebase Storage` · `Google Maps`

## Repository structure

```text
lib/
  main.dart
  screens/       # Household, tasks, lists, expenses, reminders, chat
  services/      # Auth, Firestore, notifications, location, calendar
  models/        # Application data models
  widgets/       # Reusable Flutter components
functions/       # Firebase backend functions
test/            # Tests
```

## Getting started

1. Install Flutter and configure the Android/iOS toolchain.
2. Clone this repository and run `flutter pub get`.
3. Configure your own Firebase project and the platform-specific Firebase settings. Do not reuse production credentials.
4. Run `flutter run` on a supported device or emulator.

Firebase-backed features, push notifications, maps and external APIs require their own configuration. Deployment readiness has not been independently verified.

## Why this project is interesting

The architectural challenge is keeping multi-member household data, notifications and task state consistent while handling mobile lifecycle changes and intermittent connectivity.

**Maintainer:** [Pelae Gaspro](https://github.com/pelaegaspro)
