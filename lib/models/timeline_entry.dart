import 'package:flutter/material.dart';

enum EntryType { appUsage, manual, sleep }

enum LifeCategory {
  productive,
  sleep,
  leisure,
  selfCare,
  social,
  eating,
  exercise,
  errand,
  other,
}

extension LifeCategoryExtension on LifeCategory {
  String get label {
    switch (this) {
      case LifeCategory.productive: return 'Productive';
      case LifeCategory.sleep: return 'Sleep';
      case LifeCategory.leisure: return 'Leisure';
      case LifeCategory.selfCare: return 'Self Care';
      case LifeCategory.social: return 'Social';
      case LifeCategory.eating: return 'Eating';
      case LifeCategory.exercise: return 'Exercise';
      case LifeCategory.errand: return 'Errand';
      case LifeCategory.other: return 'Other';
    }
  }

  Color get color {
    switch (this) {
      case LifeCategory.productive: return const Color(0xFF4CAF50);
      case LifeCategory.sleep: return const Color(0xFF3F51B5);
      case LifeCategory.leisure: return const Color(0xFF2196F3);
      case LifeCategory.selfCare: return const Color(0xFF9C27B0);
      case LifeCategory.social: return const Color(0xFFFF9800);
      case LifeCategory.eating: return const Color(0xFFFF5722);
      case LifeCategory.exercise: return const Color(0xFF00BCD4);
      case LifeCategory.errand: return const Color(0xFF795548);
      case LifeCategory.other: return const Color(0xFF607D8B);
    }
  }

  String get emoji {
    switch (this) {
      case LifeCategory.productive: return '💼';
      case LifeCategory.sleep: return '🌙';
      case LifeCategory.leisure: return '🎮';
      case LifeCategory.selfCare: return '🧘';
      case LifeCategory.social: return '👥';
      case LifeCategory.eating: return '🍽️';
      case LifeCategory.exercise: return '🏃';
      case LifeCategory.errand: return '🛍️';
      case LifeCategory.other: return '📌';
    }
  }
}

class TimelineEntry {
  final String id;
  final EntryType type;
  final DateTime startTime;
  final DateTime endTime;
  final String title;
  final String? description;
  final String? packageName;
  final String? moodEmoji;
  final LifeCategory? category;

  TimelineEntry({
    required this.id,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.description,
    this.packageName,
    this.moodEmoji,
    this.category,
  });

  Duration get duration => endTime.difference(startTime);

  String get durationLabel {
    final mins = duration.inMinutes;
    if (mins < 60) return '${mins}m';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return rem == 0 ? '${hrs}h' : '${hrs}h ${rem}m';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'title': title,
      'description': description,
      'packageName': packageName,
      'moodEmoji': moodEmoji,
      'category': category?.index,
    };
  }

  factory TimelineEntry.fromMap(Map<String, dynamic> map) {
    return TimelineEntry(
      id: map['id'],
      type: EntryType.values[map['type']],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime']),
      title: map['title'],
      description: map['description'],
      packageName: map['packageName'],
      moodEmoji: map['moodEmoji'],
      category: map['category'] != null
          ? LifeCategory.values[map['category']]
          : null,
    );
  }

  TimelineEntry copyWith({
    String? title,
    String? description,
    String? moodEmoji,
    LifeCategory? category,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return TimelineEntry(
      id: id,
      type: type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      title: title ?? this.title,
      description: description ?? this.description,
      packageName: packageName,
      moodEmoji: moodEmoji ?? this.moodEmoji,
      category: category ?? this.category,
    );
  }
}