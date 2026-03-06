import 'package:flutter_test/flutter_test.dart';
import 'package:crm_flutter/services/security_service.dart';

void main() {
  group('SecurityService Tests', () {
    test('hashPassword() should generate consistent SHA-256 hashes', () {
      const pass1 = 'password123';
      const pass2 = 'password123';
      const pass3 = 'differentPass';

      final hash1 = SecurityService.hashPassword(pass1);
      final hash2 = SecurityService.hashPassword(pass2);
      final hash3 = SecurityService.hashPassword(pass3);

      expect(hash1, isNotEmpty);
      expect(hash1, hash2, reason: 'Same password should yield same hash');
      expect(hash1, isNot(equals(hash3)),
          reason: 'Different passwords should yield different hashes');

      // Verify SHA-256 hash length (64 hex characters)
      expect(hash1.length, 64);
    });

    test('encryptData() and decryptData() should work symmetrically', () {
      const secretData = 'my_super_secret_taxisnet_password';

      final encrypted = SecurityService.encryptData(secretData);

      expect(encrypted, isNot(equals(secretData)),
          reason: 'Encrypted string must not match plain text');
      expect(encrypted, isNotEmpty);

      final decrypted = SecurityService.decryptData(encrypted);

      expect(decrypted, equals(secretData),
          reason: 'Decryption must return original plain text');
    });

    test('encryptData() should handle empty strings safely', () {
      final encrypted = SecurityService.encryptData('');
      expect(encrypted, '');
    });

    test('decryptData() should handle empty strings safely', () {
      final decrypted = SecurityService.decryptData('');
      expect(decrypted, '');
    });

    test('decryptData() should return error indicator on invalid base64/cipher',
        () {
      const invalidEncrypted = 'NotAValidBase64Str1ng!';
      final decrypted = SecurityService.decryptData(invalidEncrypted);

      expect(decrypted, '[Decryption Error]',
          reason: 'Should gracefully handle invalid data strings');
    });
  });
}
