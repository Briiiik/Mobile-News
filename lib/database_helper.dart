import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'liked_articles.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE liked_articles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        description TEXT,
        url TEXT,
        image TEXT
      )
    ''');
  }

  // Ajouter un article liké
  Future<void> insertArticle(Map<String, dynamic> article) async {
    final db = await database;
    await db.insert(
      'liked_articles',
      article,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Supprimer un article liké
  Future<void> deleteArticle(String url) async {
    final db = await database;
    await db.delete(
      'liked_articles',
      where: 'url = ?',
      whereArgs: [url],
    );
  }

  // Récupérer tous les articles likés
  Future<List<Map<String, dynamic>>> getLikedArticles() async {
    final db = await database;
    return await db.query('liked_articles');
  }
}