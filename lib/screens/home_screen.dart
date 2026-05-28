import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/timeline_entry.dart';
import '../services/storage_service.dart';
import '../services/usage_stats_service.dart';
import '../services/sleep_service.dart';
import '../widgets/add_entry_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDay = DateTime.now();
  List<TimelineEntry> _allEntries = [];
  bool _loading = true;
  bool _hasUsagePermission = false;
  TimelineEntry? _pendingSleep;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();
  }

  Future<void> _checkPermissionAndLoad() async {
    final granted = await UsageStatsService.checkPermission();
    setState(() => _hasUsagePermission = granted);
    if (granted) {
      await _loadDay(_selectedDay);
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadDay(DateTime day) async {
    setState(() => _loading = true);
    final manual = await StorageService.getEntriesForDay(day);
    List<TimelineEntry> appUsage = [];
    if (_hasUsagePermission) {
      appUsage = await UsageStatsService.getUsageForDay(day);
    }
    final sleep = await SleepService.detectSleep(day);
    final all = [...manual, ...appUsage];
    TimelineEntry? pendingSleep;
    if (sleep != null) {
      final alreadyConfirmed = manual.any((e) => e.type == EntryType.sleep);
      if (!alreadyConfirmed) pendingSleep = sleep;
      all.add(sleep);
    }
    all.sort((a, b) => a.startTime.compareTo(b.startTime));
    setState(() {
      _allEntries = all;
      _pendingSleep = pendingSleep;
      _loading = false;
    });
  }

  Future<void> _showAddEntry(DateTime start, DateTime end) async {
    final result = await showModalBottomSheet<TimelineEntry>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddEntryDialog(startTime: start, endTime: end),
    );
    if (result != null) {
      await StorageService.insertEntry(result);
      await _loadDay(_selectedDay);
    }
  }

  Future<void> _editEntry(TimelineEntry entry) async {
    final result = await showModalBottomSheet<TimelineEntry>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddEntryDialog(
        startTime: entry.startTime,
        endTime: entry.endTime,
        existingEntry: entry,
      ),
    );
    if (result != null) {
      await StorageService.updateEntry(result);
      await _loadDay(_selectedDay);
    }
  }

  Future<void> _deleteEntry(TimelineEntry entry) async {
    await StorageService.deleteEntry(entry.id);
    await _loadDay(_selectedDay);
  }

  void _changeDay(int offset) {
    final newDay = _selectedDay.add(Duration(days: offset));
    if (newDay.isAfter(DateTime.now())) return;
    setState(() => _selectedDay = newDay);
    _loadDay(newDay);
  }

  // Build hour blocks from 0 to 23
  List<_HourBlock> _buildHourBlocks() {
    final blocks = <_HourBlock>[];
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(_selectedDay, now);
    final lastHour = isToday ? now.hour : 23;

    // Find sleep entry (auto-detected or manual with sleep category)
      final sleepEntry = _allEntries.firstWhere(
        (e) => e.type == EntryType.sleep ||
            (e.type == EntryType.manual && e.category == LifeCategory.sleep),
        orElse: () => TimelineEntry(
          id: '', type: EntryType.sleep,
          startTime: DateTime(0), endTime: DateTime(0), title: '',
        ),
      );
      final hasSleep = sleepEntry.id.isNotEmpty;

    int hour = 0;
    while (hour <= lastHour) {
      final blockStart = DateTime(
          _selectedDay.year, _selectedDay.month, _selectedDay.day, hour);
      final blockEnd = blockStart.add(const Duration(hours: 1));

      // Check if this hour is covered by sleep
      if (hasSleep) {
        final sleepStart = sleepEntry.startTime;
        final sleepEnd = sleepEntry.endTime;
        if (blockStart.isBefore(sleepEnd) && blockEnd.isAfter(sleepStart)) {
          // Find how many consecutive hours sleep covers
          int sleepHours = 1;
          while (hour + sleepHours <= lastHour) {
            final nextStart = blockStart.add(Duration(hours: sleepHours));
            final nextEnd = nextStart.add(const Duration(hours: 1));
            if (nextStart.isBefore(sleepEnd) && nextEnd.isAfter(sleepStart)) {
              sleepHours++;
            } else {
              break;
            }
          }
          blocks.add(_HourBlock(
            hour: hour,
            spanHours: sleepHours,
            type: _HourBlockType.sleep,
            sleepEntry: sleepEntry,
          ));
          hour += sleepHours;
          continue;
        }
      }

      // Get app usage entries in this hour
      final hourEntries = _allEntries.where((e) {
        if (e.type == EntryType.sleep) return false;
        return e.startTime.isBefore(blockEnd) && e.endTime.isAfter(blockStart);
      }).toList();

      // Get manual entries in this hour
      final manualEntries = hourEntries
          .where((e) => e.type == EntryType.manual)
          .toList();
      final appEntries = hourEntries
          .where((e) => e.type == EntryType.appUsage)
          .toList();

      // Calculate total phone usage in this hour
      Duration totalUsage = Duration.zero;
      for (final e in appEntries) {
        final start = e.startTime.isBefore(blockStart) ? blockStart : e.startTime;
        final end = e.endTime.isAfter(blockEnd) ? blockEnd : e.endTime;
        totalUsage += end.difference(start);
      }

      // Aggregate app usage by app name
      final Map<String, Duration> appTotals = {};
      for (final e in appEntries) {
        final start = e.startTime.isBefore(blockStart) ? blockStart : e.startTime;
        final end = e.endTime.isAfter(blockEnd) ? blockEnd : e.endTime;
        final dur = end.difference(start);
        if (dur.inSeconds < 30) continue;
        appTotals[e.title] = (appTotals[e.title] ?? Duration.zero) + dur;
      }

      // Sort app totals by duration descending
      final sortedApps = appTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final freeMinutes = 60 - totalUsage.inMinutes;
      final isFree = appEntries.isEmpty && manualEntries.isEmpty;

      // Check if free block spans multiple hours
      if (isFree) {
        int freeSpan = 1;
        while (hour + freeSpan <= lastHour) {
          final nextHour = hour + freeSpan;
          final nextStart = DateTime(_selectedDay.year, _selectedDay.month,
              _selectedDay.day, nextHour);
          final nextEnd = nextStart.add(const Duration(hours: 1));
          // Check no entries and not sleep
          final nextEntries = _allEntries.where((e) {
            if (e.type == EntryType.sleep) return false;
            return e.startTime.isBefore(nextEnd) &&
                e.endTime.isAfter(nextStart);
          });
          bool nextIsSleep = hasSleep &&
              nextStart.isBefore(sleepEntry.endTime) &&
              nextEnd.isAfter(sleepEntry.startTime);
          if (nextEntries.isEmpty && !nextIsSleep) {
            freeSpan++;
          } else {
            break;
          }
        }
        blocks.add(_HourBlock(
          hour: hour,
          spanHours: freeSpan,
          type: _HourBlockType.free,
          appTotals: [],
          manualEntries: [],
          totalUsage: Duration.zero,
        ));
        hour += freeSpan;
        continue;
      }

      blocks.add(_HourBlock(
        hour: hour,
        spanHours: 1,
        type: _HourBlockType.mixed,
        appTotals: sortedApps,
        manualEntries: manualEntries,
        totalUsage: totalUsage,
      ));
      hour++;
    }
    return blocks;
  }

  void _showHourDetail(_HourBlock block) {
    final blockStart = DateTime(_selectedDay.year, _selectedDay.month,
        _selectedDay.day, block.hour);
    final blockEnd = blockStart.add(Duration(hours: block.spanHours));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final fmt = DateFormat('h:mm a');
        final freeMinutes = (block.spanHours * 60) - (block.totalUsage ?? Duration.zero).inMinutes;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${fmt.format(blockStart)} – ${fmt.format(blockEnd)}',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (block.appTotals != null && block.appTotals!.isNotEmpty) ...[
                Text('Apps used',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 8),
                ...block.appTotals!.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Text('📱', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(e.key, style: theme.textTheme.bodyMedium)),
                          Text(_fmtDur(e.value),
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    )),
              ],
              if (block.manualEntries != null && block.manualEntries!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Your entries',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                const SizedBox(height: 8),
                ...block.manualEntries!.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(e.moodEmoji ?? e.category?.emoji ?? '📌',
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(e.title, style: theme.textTheme.bodyMedium)),
                          Text(e.durationLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(width: 4),
                          PopupMenuButton(
                            icon: Icon(Icons.more_vert,
                                size: 16, color: theme.colorScheme.onSurfaceVariant),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    Icon(Icons.edit_outlined, size: 16),
                                    SizedBox(width: 8),
                                    Text('Edit')
                                  ])),
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [
                                    Icon(Icons.delete_outline, size: 16),
                                    SizedBox(width: 8),
                                    Text('Delete')
                                  ])),
                            ],
                            onSelected: (v) {
                              Navigator.pop(context);
                              if (v == 'edit') _editEntry(e);
                              if (v == 'delete') _deleteEntry(e);
                            },
                          ),
                        ],
                      ),
                    )),
              ],
              const SizedBox(height: 8),
              if (freeMinutes >= 30) ...[
                const Divider(),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      final freeEnd = blockStart.add(Duration(minutes: freeMinutes.clamp(30, block.spanHours * 60)));
                      _showAddEntry(blockStart, freeEnd);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add entry for this block'),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _editSleepEntry(TimelineEntry entry) async {
    TimeOfDay startTime = TimeOfDay.fromDateTime(entry.startTime);
    TimeOfDay endTime = TimeOfDay.fromDateTime(entry.endTime);

    final newStart = await showTimePicker(
      context: context,
      initialTime: startTime,
      helpText: 'Sleep start time',
    );
    if (newStart == null) return;

    final newEnd = await showTimePicker(
      context: context,
      initialTime: endTime,
      helpText: 'Sleep end time',
    );
    if (newEnd == null) return;

    final updatedStart = DateTime(
      entry.startTime.year,
      entry.startTime.month,
      entry.startTime.day,
      newStart.hour,
      newStart.minute,
    );
    final updatedEnd = DateTime(
      entry.endTime.year,
      entry.endTime.month,
      entry.endTime.day,
      newEnd.hour,
      newEnd.minute,
    );

    final updated = entry.copyWith(
      startTime: updatedStart,
      endTime: updatedEnd,
    );

    if (entry.type == EntryType.sleep) {
      await SleepService.confirmSleep(updated, _selectedDay);
      await StorageService.updateEntry(updated);
    } else {
      await StorageService.updateEntry(updated);
    }
    await _loadDay(_selectedDay);
  }

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = DateUtils.isSameDay(_selectedDay, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isToday ? 'Today' : DateFormat('EEEE').format(_selectedDay),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              DateFormat('MMMM d, y').format(_selectedDay),
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
              onPressed: () => _changeDay(-1),
              icon: const Icon(Icons.chevron_left)),
          IconButton(
              onPressed: isToday ? null : () => _changeDay(1),
              icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: !_hasUsagePermission
          ? _buildPermissionPrompt(theme)
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildTimeline(theme),
      
    );
  }

  Widget _buildTimeline(ThemeData theme) {
    final blocks = _buildHourBlocks();
    return Column(
      children: [
        if (_pendingSleep != null) _buildSleepBanner(theme),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: blocks.length,
            itemBuilder: (context, i) => _buildHourBlockWidget(blocks[i], theme),
          ),
        ),
      ],
    );
  }

  Widget _buildHourBlockWidget(_HourBlock block, ThemeData theme) {
    final blockStart = DateTime(
        _selectedDay.year, _selectedDay.month, _selectedDay.day, block.hour);
    final blockEnd = blockStart.add(Duration(hours: block.spanHours));
    final fmt = DateFormat('h:mm a');
    final timeLabel = '${fmt.format(blockStart)} – ${fmt.format(blockEnd)}';

    if (block.type == _HourBlockType.sleep) {
      return _buildBlock(
        theme: theme,
        timeLabel: timeLabel,
        dotColor: const Color(0xFF3F51B5),
        cardColor: const Color(0xFF3F51B5).withOpacity(0.1),
        borderColor: const Color(0xFF3F51B5).withOpacity(0.3),
        spanHours: block.spanHours,
        child: Row(
          children: [
            const Text('🌙', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text('Sleep',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              _fmtDur(block.sleepEntry!.duration),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            PopupMenuButton(
              icon: Icon(Icons.more_vert,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Edit')
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 16),
                      SizedBox(width: 8),
                      Text('Delete')
                    ])),
              ],
              onSelected: (v) async {
                if (v == 'edit') {
                  await _editSleepEntry(block.sleepEntry!);
                }
                if (v == 'delete') {
                  await _deleteEntry(block.sleepEntry!);
                }
              },
            ),
          ],
        ),
        onTap: null,
      );
    }

    if (block.type == _HourBlockType.free) {
      final dur = Duration(hours: block.spanHours);
      // Only show "What were you doing?" if gap >= 15 mins (always true for hour blocks >= 1hr)
      return _buildBlock(
        theme: theme,
        timeLabel: timeLabel,
        dotColor: theme.colorScheme.outlineVariant,
        cardColor: Colors.transparent,
        borderColor: theme.colorScheme.outlineVariant,
        spanHours: block.spanHours,
        isDashed: true,
        child: Row(
          children: [
            Icon(Icons.add, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'What were you doing?',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Text(
              _fmtDur(dur),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        onTap: () => _showAddEntry(blockStart, blockEnd),
      );
    }

    // Mixed block
    final appNames = block.appTotals
            ?.take(3)
            .map((e) => e.key)
            .join(' · ') ??
        '';
    final hasManual = block.manualEntries?.isNotEmpty ?? false;
    final manualSummary = hasManual
        ? block.manualEntries!.map((e) => e.title).join(' · ')
        : '';

    return _buildBlock(
      theme: theme,
      timeLabel: timeLabel,
      dotColor: theme.colorScheme.secondary,
      cardColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
      borderColor: theme.colorScheme.outlineVariant,
      spanHours: block.spanHours,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (appNames.isNotEmpty)
            Row(
              children: [
                const Text('📱', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    appNames,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _fmtDur(block.totalUsage ?? Duration.zero),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          if (hasManual) ...[
            if (appNames.isNotEmpty) const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  block.manualEntries!.first.moodEmoji ??
                      block.manualEntries!.first.category?.emoji ??
                      '📌',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    manualSummary,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      onTap: () => _showHourDetail(block),
    );
  }

  Widget _buildBlock({
    required ThemeData theme,
    required String timeLabel,
    required Color dotColor,
    required Color cardColor,
    required Color borderColor,
    required int spanHours,
    required Widget child,
    VoidCallback? onTap,
    bool isDashed = false,
  }) {
    final minHeight = (spanHours * 56.0).clamp(56.0, 300.0);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time label
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                timeLabel.split(' – ').first,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Line and dot
          Column(
            children: [
              Container(width: 2, height: 8, color: theme.colorScheme.outlineVariant),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
              ),
              Expanded(
                child: Container(width: 2, color: theme.colorScheme.outlineVariant),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  constraints: BoxConstraints(minHeight: minHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepBanner(ThemeData theme) {
    final sleep = _pendingSleep!;
    final fmt = DateFormat('h:mm a');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3F51B5).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3F51B5).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('🌙', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Looks like you slept',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF3F51B5),
                      fontWeight: FontWeight.w600,
                    )),
                Text('${fmt.format(sleep.startTime)} – ${fmt.format(sleep.endTime)}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              await SleepService.confirmSleep(sleep, _selectedDay);
              await StorageService.insertEntry(sleep);
              setState(() => _pendingSleep = null);
              await _loadDay(_selectedDay);
            },
            child: const Text('Confirm'),
          ),
          IconButton(
            onPressed: () async {
              await SleepService.dismissSleep(_selectedDay);
              setState(() => _pendingSleep = null);
            },
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionPrompt(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text('Usage Access Required',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Life Logger needs permission to track which apps you use and when, so it can automatically fill in your daily timeline.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () async {
                await UsageStatsService.requestPermission();
                await _checkPermissionAndLoad();
              },
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }
}

// Data classes
enum _HourBlockType { sleep, free, mixed }

class _HourBlock {
  final int hour;
  final int spanHours;
  final _HourBlockType type;
  final TimelineEntry? sleepEntry;
  final List<MapEntry<String, Duration>>? appTotals;
  final List<TimelineEntry>? manualEntries;
  final Duration? totalUsage;

  _HourBlock({
    required this.hour,
    required this.spanHours,
    required this.type,
    this.sleepEntry,
    this.appTotals,
    this.manualEntries,
    this.totalUsage,
  });
}