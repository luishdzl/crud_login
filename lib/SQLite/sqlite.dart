import 'dart:io';
import 'package:path/path.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite_flutter_crud/JsonModels/note_model.dart';
import 'package:sqlite_flutter_crud/JsonModels/users.dart';

class DatabaseHelper {
  final databaseName = "notes.db";
  late Database db;
  bool isInitialized = false;

  DatabaseHelper();

  Future<void> _initializeDatabase() async {
    if (isInitialized) return;
    
    String dbPath;
    if (Platform.isWindows) {
      final assetsDir = join(Directory.current.path, 'lib', 'assets');
      await Directory(assetsDir).create(recursive: true);
      dbPath = join(assetsDir, databaseName);
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      dbPath = join(docsDir.path, databaseName);
    }

    db = sqlite3.open(dbPath);

    db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        usrId INTEGER PRIMARY KEY AUTOINCREMENT,
        usrName TEXT UNIQUE,
        usrPassword TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        noteId INTEGER PRIMARY KEY AUTOINCREMENT,
        noteTitle TEXT NOT NULL,
        noteContent TEXT NOT NULL,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    isInitialized = true;
  }

  // Función helper para convertir Row a Map usando la estructura de resultados
  Map<String, dynamic> _rowToMap(ResultSet result, int rowIndex) {
    final Map<String, dynamic> map = {};
    for (var i = 0; i < result.columnNames.length; i++) {
      map[result.columnNames[i]] = result[rowIndex][i];
    }
    return map;
  }

  Future<bool> login(Users user) async {
    await _initializeDatabase();
    final stmt = db.prepare('''
      SELECT * FROM users 
      WHERE usrName = ? AND usrPassword = ?
    ''');
    final result = stmt.select([user.usrName, user.usrPassword]);
    stmt.dispose();
    return result.isNotEmpty;
  }

  Future<int> signup(Users user) async {
    await _initializeDatabase();
    final stmt = db.prepare('''
      INSERT INTO users (usrName, usrPassword) 
      VALUES (?, ?)
    ''');
    stmt.execute([user.usrName, user.usrPassword]);
    final id = db.lastInsertRowId;
    stmt.dispose();
    return id;
  }

  Future<List<NoteModel>> searchNotes(String keyword) async {
    await _initializeDatabase();
    final result = db.select(
      'SELECT * FROM notes WHERE noteTitle LIKE ?',
      ['%$keyword%']
    );
    return List.generate(result.length, (i) => NoteModel.fromMap(_rowToMap(result, i)));
  }

  Future<int> createNote(NoteModel note) async {
    await _initializeDatabase();
    final stmt = db.prepare('''
      INSERT INTO notes (noteTitle, noteContent, createdAt)
      VALUES (?, ?, ?)
    ''');
    stmt.execute([note.noteTitle, note.noteContent, note.createdAt]);
    final id = db.lastInsertRowId;
    stmt.dispose();
    return id;
  }

  Future<List<NoteModel>> getNotes() async {
    await _initializeDatabase();
    final result = db.select('SELECT * FROM notes');
    return List.generate(result.length, (i) => NoteModel.fromMap(_rowToMap(result, i)));
  }

  Future<int> deleteNote(int id) async {
    await _initializeDatabase();
    final stmt = db.prepare('DELETE FROM notes WHERE noteId = ?');
    stmt.execute([id]);
    final changes = db.getUpdatedRows();
    stmt.dispose();
    return changes;
  }

  Future<int> updateNote(String title, String content, int noteId) async {
    await _initializeDatabase();
    final stmt = db.prepare('''
      UPDATE notes 
      SET noteTitle = ?, noteContent = ? 
      WHERE noteId = ?
    ''');
    stmt.execute([title, content, noteId]);
    final changes = db.getUpdatedRows();
    stmt.dispose();
    return changes;
  }
}