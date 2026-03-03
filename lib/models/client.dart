/// ─── Client Model ─────────────────────────────────────────────────────────────
///
/// Immutable data class representing one client record in the CRM.
/// Maps 1-to-1 with a row in the `clients` SQLite table.
///
/// Lifecycle:
///   • Created via [Client(...)] constructor with named parameters.
///   • Serialised to DB with [toMap()].
///   • Deserialised from DB with [Client.fromMap(map)].
///
/// Nullability rules:
///   • [id] is null for unsaved records (assigned by SQLite AUTOINCREMENT).
///   • [filesConfirmedAt] is null until someone explicitly confirms the files.
class Client {
  // ── Identity ───────────────────────────────────────────────────────────────

  /// SQLite primary key. Null until the record has been saved to the DB.
  final int? id;

  /// Full name of the client (required, NOT NULL in DB).
  final String name;

  /// Contact phone number (10-digit Greek mobile, validated in the form).
  final String phone;

  /// Contact email address (optional, added in DB v2).
  final String email;

  // ── Greek Tax / Insurance IDs ──────────────────────────────────────────────

  /// ΑΦΜ – Greek tax identification number (9 digits).
  /// Left empty when the "ΑΦΜ" service is selected (client doesn't have one yet).
  final String afm;

  /// ΑΜΚΑ – Greek social security number (11 digits).
  /// Left empty when the "ΑΜΚΑ / ΑΜΑ" service is selected.
  final String amka;

  /// ΑΜΑ – Insurance number.
  /// Left empty when the "ΑΜΚΑ / ΑΜΑ" service is selected.
  final String ama;

  // ── Services ───────────────────────────────────────────────────────────────

  /// Comma-separated list of selected service keys, e.g.
  /// "ΑΜΚΑ / ΑΜΑ (160€), Κλειδάριθμος (20€), Custom"
  /// Parsed in the form by splitting on ", ".
  final String serviceType;

  /// Date the client record was first opened (defaults to DateTime.now()).
  final DateTime date;

  // ── Taxisnet Credentials ───────────────────────────────────────────────────

  /// True if the client already has Taxisnet access codes.
  /// Forced to false when the Κλειδάριθμος service is selected (they don't have one yet).
  final bool hasTaxisnet;

  final String taxisnetUser;

  /// Stored AES-encrypted via [SecurityService.encryptData].
  /// Always decrypt before displaying: [SecurityService.decryptData(taxisnetPass)].
  final String taxisnetPass;

  final String kleidarithmos;

  // ── Status Flags ───────────────────────────────────────────────────────────

  final String amkaAmaStatus;

  /// True if the client's request was formally rejected (aporipsi = rejection).
  final bool aporipsi;

  final String actionsToday;

  /// How the client paid: 'Μετρητά' | 'Κάρτα' | 'Iris'
  final String paymentMethod;

  /// Free-text notes about the client's request/goal.
  final String requestNotes;

  // ── Financials ─────────────────────────────────────────────────────────────

  /// Total amount billed (sum of selected services + custom).
  final double total;

  /// Amount already received from the client.
  final double paid;

  /// Remaining balance: computed as `total - paid`.
  /// Stored in DB for quick querying; always kept in sync by the form.
  final double balance;

  // ── Files ──────────────────────────────────────────────────────────────────

  /// Absolute path to the local client folder managed by [FileService].
  final String folderPath;

  final String filesConfirmedBy;

  /// Timestamp of when the files were confirmed as complete (nullable).
  final DateTime? filesConfirmedAt;

  // ── Audit Timestamps ───────────────────────────────────────────────────────

  /// Username of the user who first created this record.
  final String createdBy;

  /// Timestamp of first creation (ISO-8601, stored in DB as TEXT).
  final DateTime createdAt;

  /// Username of the user who last saved this record.
  final String lastEditedBy;

  /// Timestamp of the most recent save.
  final DateTime lastEditedAt;

  // ── Extended Fields (added progressively) ─────────────────────────────────

  final String goal;

  /// Κατάσταση Δηλώσεων: 'Μη Ορισμένη' | 'Υποβολή Ε1' | ... | 'Ολοκληρωμένη' | 'Πρόβλημα'
  final String declarationStatus;

  /// Κατάσταση Πελάτη: 'Νέος' | 'Σε επεξεργασία' | 'Αναμονή' | 'Ολοκληρωμένος' | 'Απορριφθείς'
  final String customerStatus;

  final String amount;

  final String amkaValid;

  /// Type of ID document presented:
  /// 'Ταυτότητα' | 'Άσυλο' | 'Διαβατήριο' | 'Άλλο'
  /// Added in DB v2. Defaults to 'Ταυτότητα' when reading old rows.
  final String idType;

  // ── Constructor ────────────────────────────────────────────────────────────

  Client({
    this.id,
    required this.serviceType,
    required this.date,
    required this.name,
    this.phone = '',
    this.email = '',
    this.afm = '',
    this.amka = '',
    this.ama = '',
    this.hasTaxisnet = false,
    this.taxisnetUser = '',
    this.taxisnetPass = '',
    this.kleidarithmos = '',
    this.amkaAmaStatus = '',
    this.aporipsi = false,
    this.actionsToday = '',
    this.paymentMethod = '',
    this.requestNotes = '',
    this.total = 0.0,
    this.paid = 0.0,
    this.balance = 0.0,
    this.folderPath = '',
    this.filesConfirmedBy = '',
    this.filesConfirmedAt,
    required this.createdBy,
    required this.createdAt,
    required this.lastEditedBy,
    required this.lastEditedAt,
    this.goal = '',
    this.declarationStatus = 'Μη Ορισμένη',
    this.customerStatus = 'Νέος',
    this.amount = '',
    this.amkaValid = 'Άγνωστο',
    this.idType = 'Ταυτότητα',
  });

  // ── Serialisation ──────────────────────────────────────────────────────────

  /// Converts this object to a Map suitable for SQLite insert/update.
  ///
  /// NOTE: [id] is included so that [db.update] can use it as a WHERE key,
  /// but a null id is fine for [db.insert] (SQLite ignores null PKs).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'service_type': serviceType,
      'date': date.toIso8601String(),
      'name': name,
      'phone': phone,
      'email': email,
      'afm': afm,
      'amka': amka,
      'ama': ama,
      'has_taxisnet': hasTaxisnet ? 1 : 0, // SQLite has no BOOLEAN type
      'taxisnet_user': taxisnetUser,
      'taxisnet_pass': taxisnetPass, // already encrypted
      'kleidarithmos': kleidarithmos,
      'amka_ama_status': amkaAmaStatus,
      'aporipsi': aporipsi ? 1 : 0,
      'actions_today': actionsToday,
      'payment_method': paymentMethod,
      'request_notes': requestNotes,
      'total': total,
      'paid': paid,
      'balance': balance,
      'folder_path': folderPath,
      'files_confirmed_by': filesConfirmedBy,
      'files_confirmed_at': filesConfirmedAt?.toIso8601String(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'last_edited_by': lastEditedBy,
      'last_edited_at': lastEditedAt.toIso8601String(),
      'goal': goal,
      'declaration_status': declarationStatus,
      'customer_status': customerStatus,
      'amount': amount,
      'amka_valid': amkaValid,
      'id_type': idType,
    };
  }

  /// Constructs a [Client] from a raw SQLite row map.
  ///
  /// All string fields use `?? ''` to guard against NULL columns
  /// (which can appear on rows created before a column was added via ALTER TABLE).
  ///
  /// DEBUG TIP: If a field always shows as empty after a migration, check
  /// that [_onUpgrade] ran correctly and that [fromMap] reads the right key.
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      serviceType: map['service_type'] ?? '',
      date: DateTime.parse(map['date']),
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '', // nullable in old rows (pre-v2)
      afm: map['afm'] ?? '',
      amka: map['amka'] ?? '',
      ama: map['ama'] ?? '',
      hasTaxisnet: map['has_taxisnet'] == 1,
      taxisnetUser: map['taxisnet_user'] ?? '',
      taxisnetPass: map['taxisnet_pass'] ?? '',
      kleidarithmos: map['kleidarithmos'] ?? '',
      amkaAmaStatus: map['amka_ama_status'] ?? '',
      aporipsi: map['aporipsi'] == 1,
      actionsToday: map['actions_today'] ?? '',
      paymentMethod: map['payment_method'] ?? '',
      requestNotes: map['request_notes'] ?? '',
      total: (map['total'] ?? 0.0).toDouble(),
      paid: (map['paid'] ?? 0.0).toDouble(),
      balance: (map['balance'] ?? 0.0).toDouble(),
      folderPath: map['folder_path'] ?? '',
      filesConfirmedBy: map['files_confirmed_by'] ?? '',
      filesConfirmedAt: map['files_confirmed_at'] != null
          ? DateTime.parse(map['files_confirmed_at'])
          : null,
      createdBy: map['created_by'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      lastEditedBy: map['last_edited_by'] ?? '',
      lastEditedAt: DateTime.parse(map['last_edited_at']),
      goal: map['goal'] ?? '',
      declarationStatus: map['declaration_status'] ?? 'Μη Ορισμένη',
      customerStatus: map['customer_status'] ?? 'Νέος',
      amount: map['amount'] ?? '',
      amkaValid: map['amka_valid'] ?? 'Άγνωστο',
      idType: map['id_type'] ?? 'Ταυτότητα', // default for pre-v2 rows
    );
  }
}
