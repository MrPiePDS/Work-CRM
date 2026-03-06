import 'package:flutter_test/flutter_test.dart';
import 'package:crm_flutter/models/client.dart';

void main() {
  group('Client Model Tests', () {
    test('toMap() and fromMap() should serialize and deserialize correctly',
        () {
      final now = DateTime.now();

      final originalClient = Client(
        id: 1,
        serviceType: 'ΑΜΚΑ / ΑΜΑ (160€), Custom',
        date: now,
        name: 'John Doe',
        phone: '6912345678',
        email: 'john.doe@example.com',
        afm: '123456789',
        amka: '',
        ama: '',
        hasTaxisnet: true,
        taxisnetUser: 'jdoe',
        taxisnetPass: 'encrypted_pass_123',
        kleidarithmos: '',
        amkaAmaStatus: 'Pending',
        aporipsi: false,
        actionsToday: 'Called client',
        paymentMethod: 'Κάρτα',
        requestNotes: 'Needs urgent processing',
        total: 200.0,
        paid: 50.0,
        balance: 150.0,
        folderPath: 'C:\\Clients\\John_Doe',
        filesConfirmedBy: 'admin',
        filesConfirmedAt: now,
        createdBy: 'admin',
        createdAt: now.subtract(const Duration(days: 1)),
        lastEditedBy: 'user1',
        lastEditedAt: now,
        goal: 'Get AMKA',
        declarationStatus: 'Σε επεξεργασία',
        customerStatus: 'Αναμονή',
        amount: '160',
        amkaValid: 'Ναι',
        idType: 'Διαβατήριο',
      );

      final map = originalClient.toMap();

      // Verify map contents
      expect(map['id'], 1);
      expect(map['name'], 'John Doe');
      expect(map['email'], 'john.doe@example.com');
      expect(map['aporipsi'], 0); // false -> 0
      expect(map['has_taxisnet'], 1); // true -> 1
      expect(map['total'], 200.0);

      // Reconstruct client from map
      final reconstructedClient = Client.fromMap(map);

      // Verify reconstructed client has same values
      expect(reconstructedClient.id, originalClient.id);
      expect(reconstructedClient.name, originalClient.name);
      expect(reconstructedClient.phone, originalClient.phone);
      expect(reconstructedClient.email, originalClient.email);
      expect(reconstructedClient.hasTaxisnet, originalClient.hasTaxisnet);
      expect(reconstructedClient.aporipsi, originalClient.aporipsi);
      expect(reconstructedClient.total, originalClient.total);
      expect(reconstructedClient.balance, originalClient.balance);
      expect(reconstructedClient.idType, originalClient.idType);

      // Date verification (ignoring microseconds precision loss during ISO8601 conversion if any)
      expect(reconstructedClient.createdAt.toIso8601String(),
          originalClient.createdAt.toIso8601String());
      expect(reconstructedClient.date.toIso8601String(),
          originalClient.date.toIso8601String());
    });

    test(
        'fromMap() should handle missing optional fields gracefully (backwards compatibility)',
        () {
      final now = DateTime.now();

      // A map representing an older database schema row (missing email, idType)
      final legacyMap = {
        'id': 2,
        'service_type': 'ΑΦΜ',
        'date': now.toIso8601String(),
        'name': 'Jane Doe',
        'phone': '6998765432',
        // 'email' is missing
        'afm': '',
        'amka': '',
        'ama': '',
        'has_taxisnet': 0,
        'taxisnet_user': '',
        'taxisnet_pass': '',
        'kleidarithmos': '',
        'amka_ama_status': '',
        'aporipsi': 0,
        'actions_today': '',
        'payment_method': 'Μετρητά',
        'request_notes': '',
        'total': 0.0,
        'paid': 0.0,
        'balance': 0.0,
        // 'id_type' is missing
        'created_by': 'admin',
        'created_at': now.toIso8601String(),
        'last_edited_by': 'admin',
        'last_edited_at': now.toIso8601String(),
      };

      final client = Client.fromMap(legacyMap);

      expect(client.name, 'Jane Doe');
      expect(client.email, ''); // Default fallback
      expect(client.idType, 'Ταυτότητα'); // Default fallback for existing rows
      expect(client.hasTaxisnet, false);
      expect(client.aporipsi, false);
    });
  });
}
