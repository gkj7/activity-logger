import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/timeline_entry.dart';

class StorageService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'life_logger.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id TEXT PRIMARY KEY,
            type INTEGER NOT NULL,
            startTime INTEGER NOT NULL,
            endTime INTEGER NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            packageName TEXT,
            moodEmoji TEXT,
            category INTEGER
          )
        ''');
      },
    );
  }

  static Future<void> insertEntry(TimelineEntry entry) async {
    final db = await database;
    await db.insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> updateEntry(TimelineEntry entry) async {
    final db = await database;
    await db.update(
      'entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  static Future<void> deleteEntry(String id) async {
    final db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<TimelineEntry>> getEntriesForDay(DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;
    final maps = await db.query(
      'entries',
      where: 'startTime >= ? AND startTime <= ?',
      whereArgs: [start, end],
      orderBy: 'startTime ASC',
    );
    return maps.map((m) => TimelineEntry.fromMap(m)).toList();
  }

  static Future<List<TimelineEntry>> getEntriesForRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query(
      'entries',
      where: 'startTime >= ? AND startTime <= ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'startTime ASC',
    );
    return maps.map((m) => TimelineEntry.fromMap(m)).toList();
  }
}