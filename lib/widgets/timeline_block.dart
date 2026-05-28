import 'package:flutter/material.dart';
import '../models/timeline_entry.dart';

class TimelineBlock extends StatelessWidget {
  final TimelineEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const TimelineBlock({
    super.key,
    required this.entry,
    this.onEdit,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time column
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(entry.startTime),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Line + dot
          Column(
            children: [
              Container(
                width: 2,
                height: 8,
                color: _getLineColor(theme),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getDotColor(theme),
                ),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: _getLineColor(theme),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Content card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _getBorderColor(theme),
                    width: 1,
                  ),
                ),
                color: _getCardColor(theme),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (entry.moodEmoji != null ||
                                    entry.type == EntryType.sleep) ...[
                                  Text(
                                    entry.type == EntryType.sleep
                                        ? '🌙'
                                        : entry.moodEmoji!,
                                    style:
                                        const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (entry.type == EntryType.appUsage) ...[
                                  Text('📱',
                                      style:
                                          const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(
                                    entry.title,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (entry.description != null &&
                                entry.description!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                entry.description!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (entry.category != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: entry.category!.color
                                          .withOpacity(0.15),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      entry.category!.label,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        color: entry.category!.color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  entry.durationLabel,
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (entry.type == EntryType.manual ||
                          entry.type == EntryType.sleep)
                        PopupMenuButton(
                          icon: Icon(
                            Icons.more_vert,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          itemBuilder: (context) => [
                            if (entry.type == EntryType.manual)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 18),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') onEdit?.call();
                            if (value == 'delete') onDelete?.call();
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour;
    final m = time.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m\n$period';
  }

  Color _getDotColor(ThemeData theme) {
    switch (entry.type) {
      case EntryType.sleep:
        return const Color(0xFF3F51B5);
      case EntryType.appUsage:
        return theme.colorScheme.secondary;
      case EntryType.manual:
        return entry.category?.color ?? theme.colorScheme.primary;
    }
  }

  Color _getLineColor(ThemeData theme) {
    return theme.colorScheme.outlineVariant;
  }

  Color _getCardColor(ThemeData theme) {
    switch (entry.type) {
      case EntryType.sleep:
        return const Color(0xFF3F51B5).withOpacity(0.1);
      case EntryType.appUsage:
        return theme.colorScheme.surfaceVariant.withOpacity(0.5);
      case EntryType.manual:
        return entry.category?.color.withOpacity(0.08) ??
            theme.colorScheme.surfaceVariant.withOpacity(0.5);
    }
  }

  Color _getBorderColor(ThemeData theme) {
    switch (entry.type) {
      case EntryType.sleep:
        return const Color(0xFF3F51B5).withOpacity(0.3);
      case EntryType.appUsage:
        return theme.colorScheme.outlineVariant;
      case EntryType.manual:
        return entry.category?.color.withOpacity(0.3) ??
            theme.colorScheme.outlineVariant;
    }
  }
}