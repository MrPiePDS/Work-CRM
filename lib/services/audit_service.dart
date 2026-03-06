import '../services/database_service.dart';

class AuditService {
  final _db = DatabaseService();

  Future<void> logAction(String user, String action,
      {int? customerId, String? details}) async {
    final db = await _db.database;
    await db.insert('audit_logs', {
      'timestamp': DateTime.now().toIso8601String(),
      'username': user,
      'action': action,
      'customer_id': customerId,
      'details': details ?? '',
    });
  }

  Future<List<Map<String, dynamic>>> getLogs({int? customerId}) async {
    final db = await _db.database;
    if (customerId != null) {
      return await db.query('audit_logs',
          where: 'customer_id = ?',
          whereArgs: [customerId],
          orderBy: 'timestamp DESC');
    }
    return await db.query('audit_logs', orderBy: 'timestamp DESC', limit: 100);
  }
}
