# Activity Logger

Android app that tracks your phone usage and lets you log your day in a clean 24-hour timeline.

## Features

- Auto phone usage tracking via Android Usage Stats API
- 24hr vertical timeline with hourly blocks
- Tap any block to see per-app breakdown
- Manual entries for off-phone time with mood emoji and category tags
- Auto sleep detection with confirm/edit/dismiss
- Daily and weekly stats — sleep, on-screen, off-screen time
- Material Design 3 with full dark mode support

## Built With

- Flutter
- SQLite (sqflite)
- Android Usage Stats API

## Setup

```bash
git clone https://github.com/gkj7/activity-logger.git
cd activity-logger
flutter pub get
flutter run
```

Requires Android with Usage Access permission enabled.

## License

MIT
