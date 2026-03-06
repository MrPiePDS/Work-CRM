import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import '../models/client.dart';

/// ─── DatabaseService ─────────────────────────────────────────────────────────
///
/// Singleton wrapper around the local SQLite database.
/// Uses `sqflite_common_ffi` so it works on desktop (Windows/Linux).
///
/// DB file location:
///   <ApplicationDocuments>/ClientManagerV2/crm_data.db
///
/// Tables:
///   clients    – One row per client record (see [_onCreate]).
///   users      – Login credentials (hashed passwords).
///   audit_logs – Every Create/Update action with timestamp + details.
///
/// VERSION HISTORY:
///   v1  Initial schema
///   v2  Added `email` TEXT and `id_type` TEXT columns to clients
class DatabaseService {
  // ── Singleton pattern ──────────────────────────────────────────────────────
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  /// Set this to true in unit tests to use an in-memory database.
  static bool isTestMode = false;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // ── DB access ──────────────────────────────────────────────────────────────

  /// Returns the open [Database], initialising it on first access.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Returns the absolute path of the persistent SQLite DB file.
  Future<String> getDbPath() async {
    if (isTestMode) return inMemoryDatabasePath;
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, 'ClientManagerV2', 'crm_data.db');
  }

  /// Opens (or creates) the SQLite file.
  /// On Windows/Linux, initialises the FFI bridge before opening.
  Future<Database> _initDatabase() async {
    // FFI is required for desktop support; not needed on Android/iOS
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (isTestMode) {
      path = inMemoryDatabasePath;
    } else {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      path = join(documentsDirectory.path, 'ClientManagerV2', 'crm_data.db');
    }

    return await openDatabase(
      path,
      version: 2, // bump this when the schema changes
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ── Schema ─────────────────────────────────────────────────────────────────

  /// Creates all tables on a fresh install.
  /// Also inserts the default 'admin' user (password: 1234, SHA-256 hashed).
  Future _onCreate(Database db, int version) async {
    // ── clients table ──────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_type TEXT,      -- comma-separated selected services
        date TEXT,              -- ISO-8601 date of record creation
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        afm TEXT,               -- Greek tax number (9 digits)
        amka TEXT,              -- Social security number (11 digits)
        ama TEXT,               -- Insurance number
        has_taxisnet INTEGER,   -- 0 or 1 boolean
        taxisnet_user TEXT,
        taxisnet_pass TEXT,     -- AES-encrypted via SecurityService
        kleidarithmos TEXT,
        amka_ama_status TEXT,
        aporipsi INTEGER,       -- 0 or 1 boolean (rejection flag)
        actions_today TEXT,
        payment_method TEXT,    -- Μετρητά | Κάρτα | Iris
        request_notes TEXT,
        total REAL,
        paid REAL,
        balance REAL,           -- computed: total - paid
        folder_path TEXT,       -- local path to client document folder
        files_confirmed_by TEXT,
        files_confirmed_at TEXT,
        created_by TEXT,        -- username of creator
        created_at TEXT,        -- ISO-8601
        last_edited_by TEXT,
        last_edited_at TEXT,    -- ISO-8601
        goal TEXT,
        declaration_status TEXT,
        customer_status TEXT,   -- Νέος | Σε επεξεργασία | Αναμονή | Ολοκληρωμένος | Απορριφθείς
        amount TEXT,
        amka_valid TEXT,
        id_type TEXT            -- Ταυτότητα | Άσυλο | Διαβατήριο | Άλλο
      )
    ''');

    // ── users table ────────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE,
        password_hash TEXT,     -- SHA-256 hex digest
        role TEXT,              -- 'admin' | 'user'
        created_at TEXT
      )
    ''');

    // ── audit_logs table ───────────────────────────────────────────────────
    // Every insert/update writes a row here via [insertAuditLog].
    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT,         -- ISO-8601
        username TEXT,
        action TEXT,            -- 'Create' | 'Update'
        customer_id INTEGER,    -- FK to clients.id (not enforced by SQLite)
        details TEXT
      )
    ''');

    // Default admin account (password: 1234)
    // IMPORTANT: change this password on first login in production!
    await db.insert('users', {
      'username': 'admin',
      'password_hash':
          '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459ee13f978d7c846f4', // sha256('1234')
      'role': 'admin',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Handles schema migrations when [version] is bumped.
  ///
  /// v1 → v2: Added `email` and `id_type` columns.
  ///
  /// Uses PRAGMA table_info to avoid "duplicate column" errors if the
  /// migration is somehow run twice (defensive programming).
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Inspect existing columns before altering to avoid errors
      final cols = await db.rawQuery('PRAGMA table_info(clients)');
      final existing = cols.map((c) => c['name'] as String).toSet();

      if (!existing.contains('email')) {
        await db.execute('ALTER TABLE clients ADD COLUMN email TEXT');
      }
      if (!existing.contains('id_type')) {
        await db.execute('ALTER TABLE clients ADD COLUMN id_type TEXT');
      }
    }
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  /// Inserts a new client row and writes a 'Create' audit log entry.
  /// Returns the new row's auto-generated [id].
  Future<int> insertClient(Client client) async {
    final db = await database;
    int id = await db.insert('clients', client.toMap());

    // Audit: record who created this client and when
    await insertAuditLog(
      username: client.lastEditedBy,
      action: 'Create',
      customerId: id,
      details: 'Created new client: ${client.name}',
    );

    return id;
  }

  /// Returns all client rows ordered by most-recently-created first.
  Future<List<Client>> getAllClients() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('clients', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => Client.fromMap(maps[i]));
  }

  /// Updates an existing client row and writes an 'Update' audit log entry.
  Future<int> updateClient(Client client) async {
    final db = await database;

    // Audit: record who changed this client and when
    await insertAuditLog(
      username: client.lastEditedBy,
      action: 'Update',
      customerId: client.id,
      details: 'Updated client record',
    );

    return await db.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  /// Deletes a client row by [id].
  /// NOTE: Deletion should only be allowed when customerStatus == 'Ολοκληρωμένος'
  /// (enforced by the UI layer, not here).
  Future<int> deleteClient(int id) async {
    final db = await database;
    return await db.delete(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── User Management ────────────────────────────────────────────────────────

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<Map<String, dynamic>?> verifyUser(
      String username, String password) async {
    final db = await database;
    final hash = _hashPassword(password);
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username, hash],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    // Fallback if DB is empty or corrupted (shouldn't happen due to onCreate, but just in case)
    if (username == 'admin' && password == '1234') {
      final checkAdmin =
          await db.query('users', where: 'username = ?', whereArgs: ['admin']);
      if (checkAdmin.isEmpty) {
        await createUser('admin', '1234', 'admin');
        return await verifyUser('admin', '1234');
      }
    }
    return null;
  }

  Future<void> createUser(String username, String password, String role) async {
    final db = await database;
    await db.insert(
      'users',
      {
        'username': username,
        'password_hash': _hashPassword(password),
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updatePassword(String username, String newPassword) async {
    final db = await database;
    await db.update(
      'users',
      {'password_hash': _hashPassword(newPassword)},
      where: 'username = ?',
      whereArgs: [username],
    );
  }

  Future<void> deleteUser(String username) async {
    final db = await database;
    await db.delete(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users', orderBy: 'username ASC');
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  /// Searches clients by ID, name, phone, or ΑΦΜ using a LIKE query.
  /// Returns results in insertion order (no explicit ORDER BY).
  ///
  /// DEBUG TIP: If search returns nothing unexpected, confirm the query
  /// contains the correct column references (id, name, phone, afm).
  Future<List<Client>> searchClients(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'clients',
      where: 'id LIKE ? OR name LIKE ? OR phone LIKE ? OR afm LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) => Client.fromMap(maps[i]));
  }

  // ── Audit Logs ─────────────────────────────────────────────────────────────

  /// Inserts a row into audit_logs.
  ///
  /// Called automatically by [insertClient] and [updateClient].
  /// Can also be called manually for any custom action you want to track.
  ///
  /// Parameters:
  ///   [username]   – The logged-in user performing the action.
  ///   [action]     – Short label, e.g. 'Create', 'Update', 'Delete'.
  ///   [customerId] – FK to clients.id (nullable for non-client actions).
  ///   [details]    – Human-readable description of what changed.
  Future<void> insertAuditLog({
    required String username,
    required String action,
    int? customerId,
    required String details,
  }) async {
    final db = await database;
    await db.insert('audit_logs', {
      'timestamp': DateTime.now().toIso8601String(),
      'username': username,
      'action': action,
      'customer_id': customerId,
      'details': details,
    });
  }

  /// Returns all audit log rows ordered by most-recent first.
  /// Only called when the logged-in user is admin (enforced in DashboardScreen).
  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    final db = await database;
    return await db.query('audit_logs', orderBy: 'id DESC');
  }

  /// Closes and nullifies the database instance (useful for test teardown).
  Future<void> clearDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
