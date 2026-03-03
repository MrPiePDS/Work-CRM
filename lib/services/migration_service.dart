import 'dart:io';
import 'package:excel/excel.dart';
import '../../models/client.dart';
import '../services/database_service.dart';

class MigrationService {
  final _db = DatabaseService();

  Future<int> importFromExcel(String filePath) async {
    var bytes = File(filePath).readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);
    int importedCount = 0;

    for (var table in excel.tables.keys) {
      var rows = excel.tables[table]!.rows;
      // Skip header row
      for (int i = 1; i < rows.length; i++) {
        var row = rows[i];
        if (row.isEmpty || row[0] == null) continue;

        try {
          final client = Client(
            serviceType: row[1]?.value.toString() ?? '',
            date: DateTime.tryParse(row[2]?.value.toString() ?? '') ??
                DateTime.now(),
            name: row[3]?.value.toString() ?? 'Άγνωστος',
            phone: row[4]?.value.toString() ?? '',
            afm: row[5]?.value.toString() ?? '',
            amka: row[6]?.value.toString() ?? '',
            ama: row[7]?.value.toString() ?? '',
            hasTaxisnet: row[8]?.value.toString().toLowerCase() == 'true',
            taxisnetUser: row[9]?.value.toString() ?? '',
            taxisnetPass: '',
            total: double.tryParse(row[17]?.value.toString() ?? '0') ?? 0,
            paid: double.tryParse(row[18]?.value.toString() ?? '0') ?? 0,
            balance: double.tryParse(row[19]?.value.toString() ?? '0') ?? 0,
            createdBy: 'System Migration',
            createdAt: DateTime.now(),
            lastEditedBy: 'System Migration',
            lastEditedAt: DateTime.now(),
            customerStatus: 'Μεταφερμένος',
          );

          await _db.insertClient(client);
          importedCount++;
        } catch (e) {
          print('Error importing row $i: $e'); // ignore: avoid_print
        }
      }
    }
    return importedCount;
  }
}
