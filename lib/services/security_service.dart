import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class SecurityService {
  // IMPORTANT: For production, use a secure storage like flutter_secure_storage
  // to store this key or derive it from a user password.
  static final _key = Key.fromUtf8('my_stable_32_byte_secret_key_123');
  static final _iv = IV.fromUtf8('my_stable_iv_456');
  static final _encrypter = Encrypter(AES(_key));

  /// Hashes a password using SHA-256 (matches legacy Python simple hashing for now, but can be improved)
  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Encrypts sensitive data like Taxisnet passwords
  static String encryptData(String data) {
    if (data.isEmpty) return '';
    final encrypted = _encrypter.encrypt(data, iv: _iv);
    return encrypted.base64;
  }

  /// Decrypts sensitive data
  static String decryptData(String encryptedBase64) {
    if (encryptedBase64.isEmpty) return '';
    try {
      return _encrypter.decrypt64(encryptedBase64, iv: _iv);
    } catch (e) {
      return '[Decryption Error]';
    }
  }
}
