import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class ChatDbHelper {
  static final ChatDbHelper _instance = ChatDbHelper._internal();
  factory ChatDbHelper() => _instance;

  ChatDbHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, 'heroine_chat.db');

    return await openDatabase(
      pathString,
      version: 4,
      onCreate: (db, version) async {
        // 1. 로컬 채팅 메시지 테이블 생성
        await db.execute('''
          CREATE TABLE local_chat_messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            heroine_name TEXT,
            sender TEXT,
            message_text TEXT,
            timestamp TEXT,
            is_read INTEGER DEFAULT 1
          )
        ''');

        // 2. 일일 시나리오 대본 클리어 상태 테이블 생성
        await db.execute('''
          CREATE TABLE cleared_chat_scripts(
            heroine_name TEXT,
            day INTEGER,
            timezone TEXT,
            PRIMARY KEY (heroine_name, day, timezone)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 개발 편의를 위해 테이블이 변경된 경우 기존 테이블을 버리고 새로 생성
        await db.execute('DROP TABLE IF EXISTS local_chat_messages');
        await db.execute('DROP TABLE IF EXISTS cleared_chat_scripts');
        
        await db.execute('''
          CREATE TABLE local_chat_messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            heroine_name TEXT,
            sender TEXT,
            message_text TEXT,
            timestamp TEXT,
            is_read INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE cleared_chat_scripts(
            heroine_name TEXT,
            day INTEGER,
            timezone TEXT,
            PRIMARY KEY (heroine_name, day, timezone)
          )
        ''');
      },
    );
  }

  // 메시지 삽입
  Future<int> insertMessage(String heroineName, String sender, String messageText, {int isRead = 1}) async {
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();
    final id = await db.insert(
      'local_chat_messages',
      {
        'heroine_name': heroineName,
        'sender': sender,
        'message_text': messageText,
        'timestamp': timestamp,
        'is_read': isRead,
      },
    );
    debugPrint("📂 [로컬 DB] 메시지 저장 완료 - ID: $id, 히로인: $heroineName, 발신자: $sender, 읽음여부: $isRead");
    return id;
  }

  // 메시지 조회 (최신 메시지가 리스트의 끝에 오도록 정렬하기 위해, id ASC로 받아오거나 역순 리스트 처리)
  Future<List<Map<String, dynamic>>> getMessages(String heroineName, {int limit = 50}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_chat_messages',
      where: 'heroine_name = ?',
      whereArgs: [heroineName],
      orderBy: 'id DESC',
      limit: limit,
    );
    // 최신 순(DESC)으로 조회된 리스트를 화면 출력을 위해 시간 순(ASC)으로 뒤집어서 반환
    return maps.reversed.toList();
  }

  // 최근 대화 기록 조회 (서버 LLM에 전송할 context용 - 최근 N개)
  Future<List<Map<String, String>>> getRecentContext(String heroineName, {int limit = 15}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_chat_messages',
      where: 'heroine_name = ?',
      whereArgs: [heroineName],
      orderBy: 'id DESC',
      limit: limit,
    );

    // [{"sender": "player/heroine", "text": "..."}] 구조로 정규화 및 시간 순 정렬
    return maps.reversed.map((m) {
      return {
        'sender': m['sender'].toString(),
        'text': m['message_text'].toString(),
      };
    }).toList();
  }

  // 특정 히로인과의 대화 읽음 처리
  Future<int> markMessagesAsRead(String heroineName) async {
    final db = await database;
    debugPrint("📂 [로컬 DB] $heroineName과의 대화 읽음 처리");
    return await db.update(
      'local_chat_messages',
      {'is_read': 1},
      where: 'heroine_name = ? AND is_read = 0',
      whereArgs: [heroineName],
    );
  }

  // 안 읽은 메시지 수 조회
  Future<int> getUnreadCount(String heroineName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_chat_messages',
      columns: ['COUNT(*) as count'],
      where: 'heroine_name = ? AND is_read = 0',
      whereArgs: [heroineName],
    );
    if (maps.isEmpty) return 0;
    return maps.first['count'] as int? ?? 0;
  }

  // 최신 1개 메시지 조회 (채팅 리스트 프리뷰용)
  Future<Map<String, dynamic>?> getLastMessage(String heroineName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'local_chat_messages',
      where: 'heroine_name = ?',
      whereArgs: [heroineName],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  // 특정 히로인과의 대화 초기화 (스토리 진행 시 호출)
  Future<int> clearHistory(String heroineName) async {
    final db = await database;
    debugPrint("📂 [로컬 DB] $heroineName과의 대화 기록 초기화");
    return await db.delete(
      'local_chat_messages',
      where: 'heroine_name = ?',
      whereArgs: [heroineName],
    );
  }

  // 특정 대본 클리어 여부 확인
  Future<bool> isScriptCleared(String heroineName, int day, String timezone) async {
    final db = await database;
    final maps = await db.query(
      'cleared_chat_scripts',
      where: 'heroine_name = ? AND day = ? AND timezone = ?',
      whereArgs: [heroineName, day, timezone],
    );
    return maps.isNotEmpty;
  }

  // 대본 클리어 등록
  Future<void> markScriptCleared(String heroineName, int day, String timezone) async {
    final db = await database;
    await db.insert(
      'cleared_chat_scripts',
      {
        'heroine_name': heroineName,
        'day': day,
        'timezone': timezone,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint("📂 [로컬 DB] 대본 클리어 등록 완료 - 히로인: $heroineName, Day: $day, 시간대: $timezone");
  }
}
