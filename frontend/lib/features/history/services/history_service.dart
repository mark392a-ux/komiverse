import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class HistoryEntry {
  final String title;
  final String coverUrl;
  final String sourceId;
  final String itemId;
  final String type; // manga | anime | novel
  final String progress;
  final int timestamp;

  HistoryEntry({
    required this.title,
    required this.coverUrl,
    required this.sourceId,
    required this.itemId,
    required this.type,
    required this.progress,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
    'title': title,
    'cover_url': coverUrl,
    'source_id': sourceId,
    'item_id': itemId,
    'type': type,
    'progress': progress,
    'timestamp': timestamp,
  };

  factory HistoryEntry.fromMap(Map<String, dynamic> m) => HistoryEntry(
    title: m['title'] ?? '',
    coverUrl: m['cover_url'] ?? '',
    sourceId: m['source_id'] ?? '',
    itemId: m['item_id'] ?? '',
    type: m['type'] ?? 'manga',
    progress: m['progress'] ?? '',
    timestamp: m['timestamp'] ?? 0,
  );
}

class HistoryService {
  static Database? _db;

  static Future<Database> _open() async {
    _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'komiverse_history.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE history (
          id        INTEGER PRIMARY KEY AUTOINCREMENT,
          title     TEXT,
          cover_url TEXT,
          source_id TEXT,
          item_id   TEXT,
          type      TEXT,
          progress  TEXT,
          timestamp INTEGER
        )
      '''),
    );
    return _db!;
  }

  static Future<void> addEntry(HistoryEntry entry) async {
    final db = await _open();
    final existing = await db.query(
      'history',
      where: 'source_id = ? AND item_id = ? AND type = ?',
      whereArgs: [entry.sourceId, entry.itemId, entry.type],
    );

    if (existing.isEmpty) {
      await db.insert('history', entry.toMap());
      return;
    }

    await db.update(
      'history',
      {
        'title': entry.title,
        'cover_url': entry.coverUrl,
        'progress': entry.progress,
        'timestamp': entry.timestamp,
      },
      where: 'source_id = ? AND item_id = ? AND type = ?',
      whereArgs: [entry.sourceId, entry.itemId, entry.type],
    );
  }

  static Future<List<HistoryEntry>> getAll(String type) async {
    final db = await _open();
    final rows = await db.query(
      'history',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'timestamp DESC',
    );
    return rows.map(HistoryEntry.fromMap).toList();
  }

  static Future<void> clear({String? type}) async {
    final db = await _open();
    if (type == null || type.trim().isEmpty) {
      await db.delete('history');
      return;
    }
    await db.delete('history', where: 'type = ?', whereArgs: [type]);
  }

  static Future<void> clearAll(String type) async {
    await clear(type: type);
  }

  static Future<void> clearEntry(
    String sourceId,
    String itemId, {
    String? type,
  }) async {
    final db = await _open();
    if (type == null) {
      await db.delete(
        'history',
        where: 'source_id = ? AND item_id = ?',
        whereArgs: [sourceId, itemId],
      );
      return;
    }

    await db.delete(
      'history',
      where: 'source_id = ? AND item_id = ? AND type = ?',
      whereArgs: [sourceId, itemId, type],
    );
  }
}
