import 'package:shared_preferences/shared_preferences.dart';
import '../models/timeline_entry.dart';
import 'usage_stats_service.dart';

class SleepService {
  static const String _confirmedSleepKey = 'confirmed_sleep';

  // Detect sleep for a given day by analyzing usage gaps
  static Future<TimelineEntry?> detectSleep(DateTime day) async {
    try {
      // Check if user already confirmed/edited sleep for this day
      final confirmed = await _getConfirmedSleep(day);
      if (confirmed != null) return confirmed;

      // Get usage for previous night into this morning
      final nightStart = DateTime(day.year, day.month, day.day - 1, 21, 0);
      final morningEnd = DateTime(day.year, day.month, day.day, 13, 0);
      final entries = await UsageStatsService.getUsageForDay(
          day.subtract(const Duration(days: 1)));
      final morningEntries = await UsageStatsService.getUsageForDay(day);

      final allEntries = [...entries, ...morningEntries]
          .where((e) =>
              e.startTime.isAfter(nightStart) &&
              e.startTime.isBefore(morningEnd))
          .toList();

      allEntries.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Find the longest gap with no app usage between 9pm and 9am
      DateTime? sleepStart;
      DateTime? sleepEnd;
      Duration longestGap = Duration.zero;

      // Add boundary events
      final boundaries = [
        nightStart,
        ...allEntries.map((e) => e.startTime),
        ...allEntries.map((e) => e.endTime),
        morningEnd,
      ]..sort();

      for (int i = 0; i < boundaries.length - 1; i++) {
        final gapStart = boundaries[i];
        final gapEnd = boundaries[i + 1];
        final gap = gapEnd.difference(gapStart);

        // Must be at least 3 hours to count as sleep
        if (gap > longestGap && gap.inHours >= 3) {
          longestGap = gap;
          sleepStart = gapStart;
          sleepEnd = gapEnd;
        }
      }

      if (sleepStart == null || sleepEnd == null) return null;
      if (longestGap.inHours < 3) return null;

      return TimelineEntry(
        id: 'sleep_${day.millisecondsSinceEpoch}',
        type: EntryType.sleep,
        startTime: sleepStart,
        endTime: sleepEnd,
        title: 'Sleep',
        moodEmoji: '🌙',
      );
    } catch (e) {
      return null;
    }
  }

  static Future<TimelineEntry?> _getConfirmedSleep(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_confirmedSleepKey${day.year}${day.month}${day.day}';
    final data = prefs.getString(key);
    if (data == null) return null;
    try {
      final parts = data.split(',');
      return TimelineEntry(
        id: 'sleep_${day.millisecondsSinceEpoch}',
        type: EntryType.sleep,
        startTime: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0])),
        endTime: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1])),
        title: 'Sleep',
        moodEmoji: '🌙',
      );
    } catch (e) {
      return null;
    }
  }

  static Future<void> confirmSleep(TimelineEntry entry, DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_confirmedSleepKey${day.year}${day.month}${day.day}';
    await prefs.setString(
      key,
      '${entry.startTime.millisecondsSinceEpoch},${entry.endTime.millisecondsSinceEpoch}',
    );
  }

  static Future<void> dismissSleep(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_confirmedSleepKey${day.year}${day.month}${day.day}';
    await prefs.setString(key, 'dismissed');
  }
}