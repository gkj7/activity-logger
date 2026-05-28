import 'package:flutter/material.dart';
import '../models/timeline_entry.dart';

class AddEntryDialog extends StatefulWidget {
  final DateTime startTime;
  final DateTime endTime;
  final TimelineEntry? existingEntry;

  const AddEntryDialog({
    super.key,
    required this.startTime,
    required this.endTime,
    this.existingEntry,
  });

  @override
  State<AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<AddEntryDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  LifeCategory _selectedCategory = LifeCategory.other;
  String _selectedMood = '😊';

  final List<String> _moods = [
    '😊', '😴', '😤', '😌', '🤔', '😎', '🥱', '😅', '🙂', '😐'
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingEntry?.title ?? '',
    );
    _descController = TextEditingController(
      text: widget.existingEntry?.description ?? '',
    );
    if (widget.existingEntry?.category != null) {
      _selectedCategory = widget.existingEntry!.category!;
    }
    if (widget.existingEntry?.moodEmoji != null) {
      _selectedMood = widget.existingEntry!.moodEmoji!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingEntry != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isEditing ? 'Edit Entry' : 'Add Entry',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'What were you doing?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  hintText: 'Notes (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Text('Category', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: LifeCategory.values.map((cat) {
                  final selected = _selectedCategory == cat;
                  return FilterChip(
                    label: Text('${cat.emoji} ${cat.label}'),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = cat),
                    selectedColor: cat.color.withOpacity(0.25),
                    checkmarkColor: cat.color,
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Mood', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _moods.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final mood = _moods[i];
                    final selected = _selectedMood == mood;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMood = mood),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceVariant,
                        ),
                        child: Center(
                          child: Text(mood,
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_titleController.text.trim().isEmpty) return;
                    final entry = TimelineEntry(
                      id: widget.existingEntry?.id ??
                          'manual_${widget.startTime.millisecondsSinceEpoch}',
                      type: EntryType.manual,
                      startTime: widget.startTime,
                      endTime: widget.endTime,
                      title: _titleController.text.trim(),
                      description: _descController.text.trim().isEmpty
                          ? null
                          : _descController.text.trim(),
                      moodEmoji: _selectedMood,
                      category: _selectedCategory,
                    );
                    Navigator.pop(context, entry);
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Add Entry'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}