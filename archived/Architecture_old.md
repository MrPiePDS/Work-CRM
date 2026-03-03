# Νέα Αρχιτεκτονική CRM v2 (Flutter + Dart + SQLite)

Αυτό το έγγραφο περιγράφει την αρχιτεκτονική του νέου συστήματος CRM, βασισμένο στο Flutter framework, σχεδιασμένο για να είναι εξαιρετικά ελαφρύ, γρήγορο, cross-platform και να προσφέρει μία premium εμπειρία χρήστη, αντικαθιστώντας το παλιό σύστημα Python/Excel.

## 1. Στοίβα Τεχνολογιών (Tech Stack)

*   **UI Framework:** [Flutter](https://flutter.dev/) (Για πανέμορφα, native-performance γραφικά σε Windows, iOS, Android).
*   **Γλώσσα Προγραμματισμού:** Dart (Σύγχρονη, Type-safe και ταχύτατη).
*   **Βάση Δεδομένων:** SQLite (Αποθήκευση όλων των δεδομένων σε ένα τοπικό αρχείο `.db`, προσφέροντας ταχύτητα και ασφάλεια δεδομένων).
*   **Security:** AES-256 Encryption (Για κωδικούς Taxisnet) και SHA-256 Hashing (Για κωδικούς χρηστών).
*   **Reports:** PDF Generation (Χρήση των πακέτων `pdf` και `printing`).

## 2. Δομή Φακέλων Έργου (Project Structure)

```
C:\Users\panag\Documents\Git\OuterTune\Work-CRM\
├── CRM_old\                           # (Ο παλιός Python κώδικας και τα αρχεία του Excel)
├── crm_flutter\                       # FLUTTER PROJECT ROOT
│   ├── lib\
│   │   ├── main.dart                  # Είσοδος της εφαρμογής & Theme Setup
│   │   ├── models\                    # Ορισμός των Data Models
│   │   │   └── client.dart            # Το μοντέλο Πελάτη (Mapping με SQLite)
│   │   ├── services\                  # Η "Εγκέφαλος" της εφαρμογής
│   │   │   ├── database_service.dart  # Διαχείριση SQLite (CRUD, Migrations)
│   │   │   ├── security_service.dart  # Κρυπτογράφηση & Hashing
│   │   │   ├── pdf_service.dart       # Δημιουργία και Εκτύπωση PDF
│   │   │   ├── migration_service.dart # Εργαλείο μεταφοράς από Python/Excel
│   │   │   └── file_service.dart      # Διαχείριση αρχείων & "Move from Scanner"
│   │   ├── ui\                        # User Interface
│   │   │   ├── screens\               # Dashboard, Login κτλ.
│   │   │   └── widgets\               # Client Form, Search Bar κτλ.
│   │   └── utils\                     # Helpers & Themes
│   │       └── theme.dart             # Dark / Light Mode configuration
│   └── pubspec.yaml                   # Εξαρτήσεις (sqflite, encrypt, pdf, κτλ.)
└── Architecture.md                    # Το παρόν έγγραφο
```

## 3. Σχήμα Βάσης Δεδομένων (SQLite)

Τα δεδομένα είναι πλέον οργανωμένα σε σχεσιακούς πίνακες για μέγιστη ταχύτητα αναζήτησης.

**Table: `clients`**
*   `id` (INTEGER PRIMARY KEY)
*   `name` (TEXT NOT NULL)
*   `afm`, `amka`, `ama` (TEXT)
*   `taxis_user`, `taxis_pass` (TEXT) - *(ΚΡΥΠΤΟΓΡΑΦΗΜΕΝΑ)*
*   `total`, `paid`, `balance` (REAL)
*   `customer_status` (TEXT) - (Νέος, Ολοκληρωμένος, κτλ.)
*   `created_at`, `last_edited_at` (DATETIME)

**Table: `audit_logs`**
*   `timestamp` (DATETIME)
*   `username` (TEXT)
*   `action` (TEXT)
*   `details` (TEXT)

## 4. Ασφάλεια & Βελτιώσεις (v2 vs v1)

1.  **Κρυπτογράφηση Taxisnet:** Στην έκδοση Python, οι κωδικοί ήταν σε απλό κείμενο μέσα στο Excel. Στη νέα έκδοση, αποθηκεύονται κρυπτογραφημένοι με **AES-256**. Αποκρυπτογραφούνται *μόνο* στιγμιαία όταν ο χρήστης πατήσει το εικονίδιο προβολής στο UI.
2.  **Ακεραιότητα Δεδομένων:** Το SQLite εγγυάται ότι δεν θα υπάρχουν "διπλοεγγραφές" ή κατεστραμμένα αρχεία λόγω απότομου κλεισίματος (ACID compliance).
3.  **Audit Trail:** Κάθε σημαντική αλλαγή καταγράφεται, ώστε να ξέρεις ποιος χρήστης άλλαξε τι και πότε.

## 5. Μεταφορά Δεδομένων (Migration)

Ο `MigrationService` επιτρέπει την αυτόματη ανάγνωση του παλιού `clients.xlsx` και την εισαγωγή όλων των πελατών στη νέα βάση δεδομένων, διατηρώντας το ιστορικό και τα οικονομικά στοιχεία.
