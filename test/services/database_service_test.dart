import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:crm_flutter/services/database_service.dart';
import 'package:crm_flutter/models/client.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      DatabaseService.isTestMode = true;
      dbService = DatabaseService();
      await dbService.clearDatabase();
    });

    tearDown(() async {
      await dbService.clearDatabase();
    });

    final testClient = Client(
      serviceType: 'ΑΜΚΑ / ΑΜΑ (160€)',
      date: DateTime.now(),
      name: 'Test Client',
      phone: '6900000000',
      paymentMethod: 'Μετρητά',
      total: 160.0,
      paid: 0.0,
      balance: 160.0,
      createdBy: 'admin',
      createdAt: DateTime.now(),
      lastEditedBy: 'admin',
      lastEditedAt: DateTime.now(),
    );

    test('Should insert and retrieve a client', () async {
      final db = await dbService.database;
      expect(db, isNotNull);

      // Insert
      int id = await dbService.insertClient(testClient);
      expect(id, isPositive);

      // Verify retrieval
      final clients = await dbService.getAllClients();
      expect(clients.length, 1);

      final retrieved = clients.first;
      expect(retrieved.id, id);
      expect(retrieved.name, 'Test Client');
      expect(retrieved.total, 160.0);
    });

    test('Updating a client also generates an audit log', () async {
      await dbService.insertClient(testClient);

      final clients = await dbService.getAllClients();
      final clientToUpdate = clients.first;

      final updatedClient = Client.fromMap({
        ...clientToUpdate.toMap(),
        'name': 'Updated Client Name',
        'paid': 100.0,
        'balance': 60.0,
      });

      await dbService.updateClient(updatedClient);

      final retrieved = (await dbService.getAllClients()).first;
      expect(retrieved.name, 'Updated Client Name');
      expect(retrieved.paid, 100.0);
      expect(retrieved.balance, 60.0);

      // Check Audit Logs
      final auditLogs = await dbService.getAuditLogs();
      // Should have 1 Create log and 1 Update log
      expect(auditLogs.length, 2);
      expect(auditLogs.first['action'], 'Update');
    });

    test('Search clients returns correct matching rows', () async {
      await dbService.insertClient(Client.fromMap(
          {...testClient.toMap(), 'name': 'Alex Johnson', 'afm': '123456789'}));
      await dbService.insertClient(Client.fromMap(
          {...testClient.toMap(), 'name': 'Bob Smith', 'afm': '987654321'}));

      final resultsName = await dbService.searchClients('Alex');
      expect(resultsName.length, 1);
      expect(resultsName.first.name, 'Alex Johnson');

      final resultsAfm = await dbService.searchClients('987');
      expect(resultsAfm.length, 1);
      expect(resultsAfm.first.name, 'Bob Smith');
    });

    test('Database contains admin user on creation', () async {
      final db = await dbService.database;
      final users = await db.query('users');
      expect(users.length, 1);
      expect(users.first['username'], 'admin');
    });
  });
}
