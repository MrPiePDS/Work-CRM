import 'dart:math';
import '../models/client.dart';

class MockData {
  static List<Client> getMockClients() {
    final random = Random();
    final firstNames = [
      'Γιώργος',
      'Μαρία',
      'Κώστας',
      'Ελένη',
      'Νίκος',
      'Κατερίνα',
      'Δημήτρης',
      'Αναστασία',
      'Ιωάννης',
      'Σοφία'
    ];
    final lastNames = [
      'Παπαδόπουλος',
      'Αντωνίου',
      'Γεωργίου',
      'Οικονόμου',
      'Μακρής',
      'Κωνσταντίνου',
      'Παναγιώτου',
      'Σταύρου',
      'Αθανασίου',
      'Μιχαήλ'
    ];
    final services = [
      'Λογιστικά',
      'Επιδόματα',
      'Δάνεια',
      'ΑΜΚΑ / ΑΜΑ',
      'Κλειδάριθμος',
      'ΑΦΜ',
      'Εργασία'
    ];
    final statuses = [
      'Νέος',
      'Σε επεξεργασία',
      'Αναμονή',
      'Ολοκληρωμένος',
      'Απορριφθείς'
    ];
    final idTypes = ['Ταυτότητα', 'Άσυλο', 'Διαβατήριο', 'Άλλο'];

    return List.generate(50, (index) {
      final name =
          '${firstNames[random.nextInt(firstNames.length)]} ${lastNames[random.nextInt(lastNames.length)]}';
      final service = services[random.nextInt(services.length)];
      final total = (random.nextInt(20) + 1) * 10.0;
      final paid =
          random.nextBool() ? total : (random.nextBool() ? 0.0 : total / 2);
      final hasTaxisnet = random.nextBool();

      return Client(
        id: index + 1,
        name: name,
        phone: '69${random.nextInt(90000000) + 10000000}',
        email: 'user$index@example.com',
        afm: '${random.nextInt(900000000) + 100000000}',
        amka:
            '${random.nextInt(900000) + 100000}${random.nextInt(90000) + 10000}',
        ama: '${random.nextInt(90000000) + 10000000}',
        idType: idTypes[random.nextInt(idTypes.length)],
        requestNotes: 'Αίτημα ${index + 1} για $service',
        serviceType: service,
        taxisnetUser: hasTaxisnet ? 'user$index' : '',
        taxisnetPass: hasTaxisnet ? 'pass$index' : '',
        hasTaxisnet: hasTaxisnet,
        total: total,
        paid: paid,
        balance: total - paid,
        customerStatus: statuses[random.nextInt(statuses.length)],
        date: DateTime.now().subtract(Duration(days: random.nextInt(30))),
        createdBy: 'admin',
        createdAt: DateTime.now().subtract(Duration(days: random.nextInt(30))),
        lastEditedBy: 'admin',
        lastEditedAt:
            DateTime.now().subtract(Duration(days: random.nextInt(10))),
      );
    });
  }
}
