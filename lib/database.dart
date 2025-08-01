import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  // Initialize the databaseFactory to databaseFactoryFfi
  static void initialize() {
    databaseFactory = databaseFactoryFfi;
  }

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final appDocumentDirectory = await getApplicationDocumentsDirectory();
      final path = join(appDocumentDirectory.path, 'emp.db');
      print('Database path: $path'); // Print the database path

      // Initialize the databaseFactory to databaseFactoryFfi
      databaseFactory = databaseFactoryFfi;

      final database = await openDatabase(
        path,
        version: 6,
        onCreate: _createTable,
      );

      print('Database opened successfully');
      return database;
    } catch (e) {
      print('Error initializing the database: $e');
      return Future.error('Error initializing the database: $e');
    }
  }

  Future<void> _createTable(Database db, int version) async {
    await db.execute('''
    CREATE TABLE Ticket (
      ticketID INTEGER PRIMARY KEY AUTOINCREMENT,
      employeeID TEXT NOT NULL,
      employeeName TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      isPrivate INTEGER NOT NULL,
      createdDate TEXT NOT NULL,
      category TEXT NOT NULL,
      referredToEmployeeID TEXT NOT NULL
    )
  ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS CheckInOut (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      employeeID TEXT,
      checkDate TEXT,
      checkType TEXT,
      checkTime TEXT
    )
  ''');
  }
}
