# Mote'z Notes

A cross-platform Flutter app for writing music notation and guitar tab using an on-screen "keyboard", a purpose-built input keyboard for entering notes, rests, chords, and articulations directly onto a rendered music staff.

## What it does

- **Notation entry** — Enter notes/rests onto a live-rendered staff using the bundled Bravura (SMuFL) music font, with support for key signatures, time signatures, tempo, and beaming.
- **Multiple keyboard layouts** — Switch between standard note-entry, symbol-based entry, letter-name entry, and dynamics keyboards.
- **Guitar tab mode** — Dedicated fret/string input, techniques (bends, mutes, harmonics), and a favourites panel for common guitar figures. A drum-tab keyboard mode also exists in the code but is currently disabled/unfinished.
- **Sheet management** — Create and configure new sheets (title, format, key/time signature, tempo) from a home screen showing a library of saved sheets with previews.
- **Accounts & sync** — Sign up/log in (with email verification), with sheets stored locally (SQLite) and synced to Firebase Cloud Firestore when signed in.
- **Export & sharing** — Export sheets to PDF, save as an image to the device gallery, or share via the OS share sheet.
- **Settings & localization** — In-app settings screen; UI strings are generated from ARB files for localization support.

## Platforms

Builds for Android, iOS, Windows, macOS, Linux, and Web.

## Tech stack

Flutter/Dart, Provider for state management, sqflite for local storage, Firebase (Auth + Firestore) for accounts and sync, and the `pdf`/`printing`/`screenshot`/`gal`/`share_plus` packages for exporting and sharing sheets.

## Getting started

This is a standard Flutter project:

```
flutter pub get
flutter run
```

For help getting started with Flutter development, view the [online documentation](https://docs.flutter.dev), which offers tutorials, samples, guidance on mobile development, and a full API reference.

### Assets

The `assets` directory houses images, fonts, and other files bundled with the app, including the Bravura music notation font used to render the staff.

### Localization

This project generates localized messages from ARB files in `lib/src/localization`. To support additional languages, see the tutorial on [Internationalizing Flutter apps](https://flutter.dev/to/internationalization).
