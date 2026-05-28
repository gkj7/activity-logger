import 'package:flutter/material.dart';
import '../models/timeline_entry.dart';
import '../services/storage_service.dart';
import '../services/usage_stats_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TimelineEntry> _entries = [];
  Duration _totalScreenTime = Duration.zero;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => _loadData());
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    DateTime start;
    switch (_tabController.index) {
      case 0:
        start = DateTime(now.year, now.month, now.day);
        break;
      case 1:
        final weekday = now.weekday;
        start = DateTime(now.year, now.month, now.day - (weekday - 1));
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
    }

    final entries = await StorageService.getEntriesForRange(start, now);
    final screenTime =
        await UsageStatsService.getTotalScreenTimeForRange(start, now);

    setState(() {
      _entries = entries;
      _totalScreenTime = screenTime;
      _loading = false;
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sleepEntries = _entries.where((e) =>
        e.type == EntryType.sleep ||
        (e.type == EntryType.manual && e.category == LifeCategory.sleep));
    final manualEntries = _entries.where((e) => e.type == EntryType.manual);

    final totalSleep =
        sleepEntries.fold(Duration.zero, (a, b) => a + b.duration);
    final totalLogged =
        manualEntries.fold(Duration.zero, (a, b) => a + b.duration);
    final totalOnScreen = _totalScreenTime;

    final now = DateTime.now();
    final Duration periodDuration;
    switch (_tabController.index) {
      case 0:
        periodDuration = const Duration(days: 1);
        break;
      case 1:
        final weekday = now.weekday;
        periodDuration = Duration(days: weekday);
        break;
      default:
        periodDuration = const Duration(days: 1);
    }

    final totalOffScreen = periodDuration - totalSleep - totalOnScreen;
    final grandTotal = totalSleep + totalOnScreen +
        (totalOffScreen.isNegative ? Duration.zero : totalOffScreen);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Day'),
            Tab(text: 'Week'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manual entries logged',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(totalLogged),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'time logged outside of phone use',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Breakdown',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  theme: theme,
                  emoji: '🌙',
                  label: 'Sleep',
                  duration: totalSleep,
                  total: grandTotal,
                  color: const Color(0xFF3F51B5),
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  theme: theme,
                  emoji: '📱',
                  label: 'On-screen',
                  duration: totalOnScreen,
                  total: grandTotal,
                  color: const Color(0xFFFF9800),
                ),
                const SizedBox(height: 12),
                _buildStatRow(
                  theme: theme,
                  emoji: '📵',
                  label: 'Off-screen',
                  duration: totalOffScreen.isNegative
                      ? Duration.zero
                      : totalOffScreen,
                  total: grandTotal,
                  color: const Color(0xFF4CAF50),
                ),
              ],
            ),
    );
  }

  Widget _buildStatRow({
    required ThemeData theme,
    required String emoji,
    required String label,
    required Duration duration,
    required Duration total,
    required Color color,
  }) {
    final percent = total.inMinutes == 0
        ? 0.0
        : (duration.inMinutes / total.inMinutes).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              _formatDuration(duration),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}