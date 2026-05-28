import 'package:usage_stats/usage_stats.dart';
import 'package:flutter/services.dart';
import '../models/timeline_entry.dart';

class UsageStatsService {
  static Future<bool> checkPermission() async {
    try {
      bool? granted = await UsageStats.checkUsagePermission();
      return granted ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> requestPermission() async {
    await UsageStats.grantUsagePermission();
  }

  static Future<List<TimelineEntry>> getUsageForDay(DateTime day) async {
    try {
      final start = DateTime(day.year, day.month, day.day);
      final end = DateTime(day.year, day.month, day.day, 23, 59, 59);

      List<EventUsageInfo> events = await UsageStats.queryEvents(start, end);

      List<TimelineEntry> entries = [];
      Map<String, DateTime> appStartTimes = {};

      // Filter out our own app and system stuff
      const ignoredPackages = {
        'com.example.life_logger',
        'android',
        'com.android.systemui',
        'com.android.launcher3',
        'com.miui.home',
        'com.sec.android.app.launcher',
        'com.google.android.apps.nexuslauncher',
        'com.oneplus.launcher',
        'com.nothing.launcher',
      };

      for (final event in events) {
        final package = event.packageName ?? '';
        if (ignoredPackages.contains(package)) continue;
        if (package.isEmpty) continue;

        final eventTime = DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(event.timeStamp ?? '0') ?? 0,
        );

        // Event type 1 = app moved to foreground
        // Event type 2 = app moved to background
        if (event.eventType == '1') {
          appStartTimes[package] = eventTime;
        } else if (event.eventType == '2') {
          final startTime = appStartTimes[package];
          if (startTime != null) {
            final duration = eventTime.difference(startTime);
            // Only log if used for more than 30 seconds
            if (duration.inSeconds > 30) {
              entries.add(TimelineEntry(
                id: '${package}_${startTime.millisecondsSinceEpoch}',
                type: EntryType.appUsage,
                startTime: startTime,
                endTime: eventTime,
                title: _getAppName(package),
                packageName: package,
              ));
            }
            appStartTimes.remove(package);
          }
        }
      }

      // Sort by start time
      entries.sort((a, b) => a.startTime.compareTo(b.startTime));
      return entries;
    } catch (e) {
      return [];
    }
  }

  static String _getAppName(String packageName) {
    const knownApps = {
      'com.google.android.youtube': 'YouTube',
      'com.instagram.android': 'Instagram',
      'com.whatsapp': 'WhatsApp',
      'com.twitter.android': 'Twitter/X',
      'com.facebook.katana': 'Facebook',
      'com.spotify.music': 'Spotify',
      'com.netflix.mediaclient': 'Netflix',
      'com.google.android.gm': 'Gmail',
      'com.google.android.apps.maps': 'Google Maps',
      'com.android.chrome': 'Chrome',
      'org.mozilla.firefox': 'Firefox',
      'com.google.android.apps.messaging': 'Messages',
      'com.telegram.messenger': 'Telegram',
      'com.snapchat.android': 'Snapchat',
      'com.reddit.frontpage': 'Reddit',
      'com.linkedin.android': 'LinkedIn',
      'com.amazon.mShop.android.shopping': 'Amazon',
      'com.google.android.apps.photos': 'Photos',
      'com.google.android.dialer': 'Phone',
      'com.android.settings': 'Settings',
      'com.google.android.calculator': 'Calculator',
      'com.miui.gallery': 'Gallery',
      'com.sec.android.gallery3d': 'Gallery',
    };

    if (knownApps.containsKey(packageName)) {
      return knownApps[packageName]!;
    }

    // Extract readable name from package name
    final parts = packageName.split('.');
    if (parts.length >= 2) {
      final name = parts.last;
      return name[0].toUpperCase() + name.substring(1);
    }
    return packageName;
  }
  static Future<Duration> getTotalScreenTimeForRange(
      DateTime start, DateTime end) async {
    try {
      Duration total = Duration.zero;
      DateTime current = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);

      while (!current.isAfter(endDay)) {
        final entries = await getUsageForDay(current);
        for (final e in entries) {
          total += e.duration;
        }
        current = current.add(const Duration(days: 1));
      }
      return total;
    } catch (e) {
      return Duration.zero;
    }
  }
}