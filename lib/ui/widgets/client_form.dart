import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/client.dart';
import '../../services/database_service.dart';
import '../../services/file_service.dart';
import '../../services/security_service.dart';

// ────────────────────────────────────────────────────────────────────────────
/// Per-service required-document checklist.
///
/// Keys must exactly match the keys in [_ClientFormState._availableServices].
/// When a service is checked in the form, its document list is merged into the
/// checklist widget ([_buildDocumentChecklist]).
// ────────────────────────────────────────────────────────────────────────────
const Map<String, List<String>> _kServiceDocs = {
  'ΑΜΚΑ / ΑΜΑ (160€)': [
    'Ταυτότητα ή Διαβατήριο',
    'Βεβαίωση ΑΜΚΑ (αν υπάρχει ήδη)',
    'Φωτογραφία τύπου ταυτότητας',
    'Βεβαίωση μόνιμης κατοικίας',
  ],
  'Κλειδάριθμος (20€)': [
    'Ταυτότητα ή Διαβατήριο',
    'Υπεύθυνη Δήλωση (Ν.1599)',
    'Αίτηση Κλειδαρίθμου (συμπληρωμένη)',
  ],
  'Μεταβολή (20€)': [
    'Ταυτότητα ή Διαβατήριο',
    'Βεβαίωση Μεταβολής (αν υπάρχει)',
    'Βεβαίωση νέας διεύθυνσης / κατοικίας',
  ],
  'ΑΦΜ (50€)': [
    'Ταυτότητα ή Διαβατήριο',
    'Αποδεικτικό κατοικίας (λογαριασμός/μισθωτήριο)',
    'Αίτηση έκδοσης ΑΦΜ',
  ],
  'Εργασία (75€)': [
    'Ταυτότητα ή Διαβατήριο',
    'Σύμβαση Εργασίας',
    'Τελευταίο εκκαθαριστικό (αν υπάρχει)',
  ],
};

/// ─── ClientForm ────────────────────────────────────────────────────────────
///
/// A [StatefulWidget] that renders the full client data-entry form.
///
/// Two modes (controlled by [isDialog]):
///   • isDialog = true  – Displayed inside a [Dialog]; shows a close (×) button
///                        and calls [Navigator.pop(true)] after saving.
///   • isDialog = false – Embedded as a persistent tab; calls [onSaved] after
///                        saving and resets itself for the next entry.
///
/// State variables:
///   [_selectedServices]       – Currently ticked service checkboxes.
///   [_hasCustomService]       – True when the Custom checkbox is ticked.
///   [_customServiceAmount]    – € value entered in the Custom text field.
///   [_status]                 – Κατάσταση Πελάτη dropdown value.
///   [_declarationStatus]      – Κατάσταση Δηλώσεων dropdown value.
///   [_paymentMethod]          – Τρόπος Πληρωμής dropdown value.
///   [_idType]                 – Τύπος Ταυτοποίησης dropdown value.
///   [_hasTaxis]               – Whether the client has Taxisnet credentials.
///   [_clientFiles]            – Files currently in the client's local folder.
///
/// Conditional field logic (driven by selected services):
///   • ΑΜΚΑ/ΑΜΑ selected  → hide ΑΜΚΑ + ΑΜΑ text fields
///   • ΑΦΜ selected        → hide ΑΦΜ text field
///   • Κλειδάριθμος sel.  → disable "Διαθέτει κωδικούς" checkbox
class ClientForm extends StatefulWidget {
  /// The client to edit, or null to create a new one.
  final Client? client;

  /// Username of the currently logged-in user (written to audit logs).
  final String user;

  /// Controls the dialog/tab dual-mode behaviour (see class doc).
  final bool isDialog;

  /// Callback fired after a successful save in tab mode.
  final VoidCallback? onSaved;

  const ClientForm({
    super.key,
    this.client,
    required this.user,
    this.isDialog = false,
    this.onSaved,
  });

  @override
  State<ClientForm> createState() => _ClientFormState();
}

// ────────────────────────────────────────────────────────────────────────────
class _ClientFormState extends State<ClientForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _afmController;
  late TextEditingController _amkaController;
  late TextEditingController _amaController;
  late TextEditingController _taxisUserCtrl;
  late TextEditingController _taxisPassCtrl;
  late TextEditingController _goalCtrl;
  late TextEditingController _totalCtrl;
  late TextEditingController _paidCtrl;
  late TextEditingController _balanceCtrl;

  // Dropdowns / booleans
  String _status = 'Νέος';
  String _declarationStatus = 'Μη Ορισμένη';
  String _paymentMethod = 'Μετρητά';
  String _idType = 'Ταυτότητα';
  bool _hasTaxis = false;
  bool _taxisVisible = false;

  // Services
  final Map<String, double> _availableServices = {
    'ΑΜΚΑ / ΑΜΑ (160€)': 160.0,
    'Κλειδάριθμος (20€)': 20.0,
    'Μεταβολή (20€)': 20.0,
    'ΑΦΜ (50€)': 50.0,
    'Εργασία (75€)': 75.0,
  };
  final List<String> _selectedServices = [];
  double _customServiceAmount = 0.0;
  bool _hasCustomService = false;

  // Files
  List<File> _clientFiles = [];

  // ── Computed helpers ───────────────────────────────────────────────────────
  bool get _amkaServiceSelected =>
      _selectedServices.contains('ΑΜΚΑ / ΑΜΑ (160€)');
  bool get _afmServiceSelected => _selectedServices.contains('ΑΦΜ (50€)');
  bool get _kleidarithmosServiceSelected =>
      _selectedServices.contains('Κλειδάριθμος (20€)');

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _afmController = TextEditingController(text: c?.afm ?? '');
    _amkaController = TextEditingController(text: c?.amka ?? '');
    _amaController = TextEditingController(text: c?.ama ?? '');
    _goalCtrl = TextEditingController(text: c?.requestNotes ?? '');
    _taxisUserCtrl = TextEditingController(text: c?.taxisnetUser ?? '');
    _taxisPassCtrl = TextEditingController(
      text: SecurityService.decryptData(c?.taxisnetPass ?? ''),
    );
    _totalCtrl = TextEditingController(text: (c?.total ?? 0.0).toString());
    _paidCtrl = TextEditingController(text: (c?.paid ?? 0.0).toString());
    _balanceCtrl = TextEditingController(text: (c?.balance ?? 0.0).toString());

    if (c != null) {
      _status = c.customerStatus.isNotEmpty ? c.customerStatus : 'Νέος';
      _declarationStatus =
          c.declarationStatus.isNotEmpty ? c.declarationStatus : 'Μη Ορισμένη';
      _hasTaxis = c.hasTaxisnet;
      _paymentMethod = c.paymentMethod.isNotEmpty ? c.paymentMethod : 'Μετρητά';
      _idType = c.idType.isNotEmpty ? c.idType : 'Ταυτότητα';

      if (c.serviceType.isNotEmpty) {
        _selectedServices.addAll(c.serviceType.split(', ').where((s) =>
            s.isNotEmpty &&
            s != 'Custom' &&
            _availableServices.containsKey(s)));
        if (c.serviceType.contains('Custom')) {
          _hasCustomService = true;
          double fixedTotal = 0;
          for (var s in _selectedServices) {
            fixedTotal += _availableServices[s]!;
          }
          if (c.total > fixedTotal) {
            _customServiceAmount = c.total - fixedTotal;
          }
        }
      }
      // Load existing files
      _loadClientFiles(c.name);
    }

    _totalCtrl.addListener(_calcBalance);
    _paidCtrl.addListener(_calcBalance);
  }

  Future<void> _loadClientFiles(String name) async {
    if (name.isEmpty) return;
    final files = await FileService.listClientFiles(name);
    if (mounted) setState(() => _clientFiles = files);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _afmController.dispose();
    _amkaController.dispose();
    _amaController.dispose();
    _goalCtrl.dispose();
    _taxisUserCtrl.dispose();
    _taxisPassCtrl.dispose();
    _totalCtrl.dispose();
    _paidCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  // ── Calculations ───────────────────────────────────────────────────────────
  void _calcTotals() {
    double total = 0;
    for (var s in _selectedServices) {
      total += _availableServices[s]!;
    }
    if (_hasCustomService) total += _customServiceAmount;
    _totalCtrl.text = total.toStringAsFixed(2);
    _calcBalance();
  }

  void _calcBalance() {
    double total = double.tryParse(_totalCtrl.text) ?? 0;
    double paid = double.tryParse(_paidCtrl.text) ?? 0;
    _balanceCtrl.text = (total - paid).toStringAsFixed(2);
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedServices.isEmpty && !_hasCustomService) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Παρακαλούμε επιλέξτε τουλάχιστον 1 υπηρεσία.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final client = Client(
      id: widget.client?.id,
      name: _nameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      afm: _afmServiceSelected ? '' : _afmController.text,
      amka: _amkaServiceSelected ? '' : _amkaController.text,
      ama: _amkaServiceSelected ? '' : _amaController.text,
      requestNotes: _goalCtrl.text,
      serviceType:
          [..._selectedServices, if (_hasCustomService) 'Custom'].join(', '),
      taxisnetUser: _taxisUserCtrl.text,
      taxisnetPass: SecurityService.encryptData(_taxisPassCtrl.text),
      hasTaxisnet: _kleidarithmosServiceSelected ? false : _hasTaxis,
      paymentMethod: _paymentMethod,
      total: double.tryParse(_totalCtrl.text) ?? 0,
      paid: double.tryParse(_paidCtrl.text) ?? 0,
      balance: double.tryParse(_balanceCtrl.text) ?? 0,
      customerStatus: _status,
      idType: _idType,
      date: widget.client?.date ?? DateTime.now(),
      createdBy: widget.client?.createdBy ?? widget.user,
      createdAt: widget.client?.createdAt ?? DateTime.now(),
      lastEditedBy: widget.user,
      lastEditedAt: DateTime.now(),
    );

    if (widget.client == null) {
      await DatabaseService().insertClient(client);
    } else {
      await DatabaseService().updateClient(client);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ο πελάτης αποθηκεύτηκε επιτυχώς!')),
      );
      if (widget.isDialog) {
        Navigator.of(context).pop(true);
      } else {
        _resetForm();
        widget.onSaved?.call();
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _afmController.clear();
    _amkaController.clear();
    _amaController.clear();
    _goalCtrl.clear();
    _totalCtrl.text = '0.0';
    _paidCtrl.text = '0.0';
    _balanceCtrl.text = '0.0';
    _selectedServices.clear();
    _hasCustomService = false;
    _customServiceAmount = 0.0;
    _status = 'Νέος';
    _declarationStatus = 'Μη Ορισμένη';
    _paymentMethod = 'Μετρητά';
    _idType = 'Ταυτότητα';
    _hasTaxis = false;
    _taxisVisible = false;
    _taxisUserCtrl.clear();
    _taxisPassCtrl.clear();
    _clientFiles.clear();
    setState(() {});
  }

  // ── File import ────────────────────────────────────────────────────────────
  Future<void> _importFile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Συμπληρώστε πρώτα το Ονοματεπώνυμο για τη δημιουργία φακέλου.')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final pickedPath = result.files.first.path;
    if (pickedPath == null) return;

    // Show rename dialog
    final docTypes = [
      'Ταυτότητα',
      'Διαβατήριο',
      'ΑΦΜ',
      'ΑΜΚΑ',
      'ΑΜΑ',
      'Σύμβαση Εργασίας',
      'Βεβαίωση Κατοικίας',
      'Υπεύθυνη Δήλωση',
      'Εκκαθαριστικό',
      'Άλλο',
    ];
    String selectedDocType = docTypes.first;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Εισαγωγή Εγγράφου'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Αρχείο: ${pickedPath.split(Platform.pathSeparator).last}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                const Text('Τύπος Εγγράφου:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedDocType,
                  items: docTypes
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setDlg(() => selectedDocType = v!),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Θα αποθηκευτεί ως: ${selectedDocType}_${DateTime.now().millisecondsSinceEpoch}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Ακύρωση')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Εισαγωγή')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await FileService.importFile(
      clientName: name,
      sourceFile: File(pickedPath),
      docType: selectedDocType,
    );
    await _loadClientFiles(name);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Το αρχείο "$selectedDocType" εισήχθη.')),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.client != null;
    final theme = Theme.of(context);

    return Container(
      width: widget.isDialog ? 1100 : double.infinity,
      height: widget.isDialog ? 780 : null,
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ─────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Επεξεργασία Πελάτη' : 'Νέος Πελάτης',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (isEdit) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'Πελάτης #${widget.client!.id}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(widget.client!.createdAt),
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                  if (widget.isDialog) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x),
                    ),
                  ],
                ],
              ),
              const Divider(height: 28),

              // ── Section 1: Basic Info ──────────────────────────────────
              _sectionTitle('Στοιχεία Πελάτη', LucideIcons.user),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      flex: 2,
                      child: _buildField('Ονοματεπώνυμο', _nameController,
                          required: true)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildField('Τηλέφωνο', _phoneController,
                          maxLength: 10,
                          exactLength: 10,
                          isNumericString: true)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildField('Email', _emailController,
                          keyboardType: TextInputType.emailAddress)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration:
                          const InputDecoration(labelText: 'Κατάσταση Πελάτη'),
                      items: [
                        'Νέος',
                        'Σε επεξεργασία',
                        'Αναμονή',
                        'Ολοκληρωμένος',
                        'Απορριφθείς'
                      ]
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) => setState(() => _status = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _declarationStatus,
                      decoration: const InputDecoration(
                          labelText: 'Κατάσταση Δηλώσεων'),
                      items: [
                        'Μη Ορισμένη',
                        'Υποβολή Ε1',
                        'Υποβολή Ε2',
                        'Υποβολή Ε3',
                        'Αναμονή Απάντησης',
                        'Ολοκληρωμένη',
                        'Πρόβλημα'
                      ]
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _declarationStatus = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _idType,
                      decoration: const InputDecoration(
                          labelText: 'Τύπος Ταυτοποίησης'),
                      items: ['Ταυτότητα', 'Άσυλο', 'Διαβατήριο', 'Άλλο']
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) => setState(() => _idType = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Section 2: Services ────────────────────────────────────
              _sectionTitle('Υπηρεσίες', LucideIcons.briefcase),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16.0,
                runSpacing: 4.0,
                children: [
                  ..._availableServices.keys.map((serviceName) {
                    bool isChecked = _selectedServices.contains(serviceName);
                    return SizedBox(
                      width: 220,
                      child: CheckboxListTile(
                        title: Text(serviceName,
                            style: const TextStyle(fontSize: 13)),
                        value: isChecked,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedServices.add(serviceName);
                            } else {
                              _selectedServices.remove(serviceName);
                            }
                            _calcTotals();
                          });
                        },
                      ),
                    );
                  }),
                  // Custom service
                  SizedBox(
                    width: 220,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _hasCustomService,
                          onChanged: (bool? value) {
                            setState(() {
                              _hasCustomService = value ?? false;
                              if (!_hasCustomService) {
                                _customServiceAmount = 0.0;
                              }
                              _calcTotals();
                            });
                          },
                        ),
                        const Text('Custom: ', style: TextStyle(fontSize: 13)),
                        if (_hasCustomService)
                          Expanded(
                            child: SizedBox(
                              height: 35,
                              child: TextField(
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 0),
                                  hintText: 'Ποσό (€)',
                                ),
                                onChanged: (val) {
                                  _customServiceAmount =
                                      double.tryParse(val) ?? 0.0;
                                  _calcTotals();
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Section 3: Required Documents ──────────────────────────
              if (_selectedServices.isNotEmpty || _hasCustomService) ...[
                _sectionTitle('Απαιτούμενα Έγγραφα', LucideIcons.clipboardList),
                const SizedBox(height: 8),
                _buildDocumentChecklist(),
                const SizedBox(height: 20),
              ],

              // ── Section 4: Conditional Client Fields ───────────────────
              _sectionTitle('Στοιχεία Εγγράφων', LucideIcons.fileText),
              const SizedBox(height: 12),

              // AFM – hidden if ΑΦΜ service selected
              if (!_afmServiceSelected) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        'ΑΦΜ',
                        _afmController,
                        maxLength: 9,
                        exactLength: 9,
                        isNumericString: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(child: SizedBox()),
                    const SizedBox(width: 16),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // AMKA + AMA – hidden if ΑΜΚΑ/ΑΜΑ service selected
              if (!_amkaServiceSelected) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        'ΑΜΚΑ',
                        _amkaController,
                        maxLength: 11,
                        exactLength: 11,
                        isNumericString: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildField(
                        'ΑΜΑ',
                        _amaController,
                        maxLength: 20,
                        isNumericString: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Taxisnet – disabled if Κλειδάριθμος selected
              _sectionTitle('Στοιχεία Taxisnet', LucideIcons.lock),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _kleidarithmosServiceSelected ? false : _hasTaxis,
                    onChanged: _kleidarithmosServiceSelected
                        ? null
                        : (v) => setState(() => _hasTaxis = v!),
                  ),
                  Text(
                    'Διαθέτει κωδικούς',
                    style: TextStyle(
                      color: _kleidarithmosServiceSelected ? Colors.grey : null,
                    ),
                  ),
                  if (_kleidarithmosServiceSelected)
                    const Text(
                      '  (δεν διαθέτει – απαιτείται Κλειδάριθμος)',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontStyle: FontStyle.italic),
                    ),
                ],
              ),
              if (!_kleidarithmosServiceSelected && _hasTaxis) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _buildField('Username', _taxisUserCtrl,
                            maxLength: 64)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildField(
                        'Password',
                        _taxisPassCtrl,
                        obscure: !_taxisVisible,
                        maxLength: 64,
                        suffix: IconButton(
                          icon: Icon(
                            _taxisVisible
                                ? LucideIcons.eye
                                : LucideIcons.eyeOff,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _taxisVisible = !_taxisVisible),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // ── Section 5: Client Folder / Files ───────────────────────
              if (isEdit || _nameController.text.trim().isNotEmpty) ...[
                _sectionTitle('Φάκελος Πελάτη', LucideIcons.folder),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => FileService.openClientFolderInExplorer(
                          _nameController.text.trim().isNotEmpty
                              ? _nameController.text.trim()
                              : (widget.client?.name ?? '')),
                      icon: const Icon(LucideIcons.folderOpen, size: 16),
                      label: const Text('Άνοιγμα στον Explorer'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _importFile,
                      icon: const Icon(LucideIcons.upload, size: 16),
                      label: const Text('Εισαγωγή Εγγράφου'),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_clientFiles.length} αρχεία',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                if (_clientFiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _clientFiles.map((f) {
                      final name = f.path.split(Platform.pathSeparator).last;
                      return Chip(
                        avatar: const Icon(LucideIcons.file, size: 14),
                        label: Text(name, style: const TextStyle(fontSize: 11)),
                        onDeleted: null,
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
              ],

              // ── Section 6: Notes ───────────────────────────────────────
              _sectionTitle('Στόχος / Σημειώσεις', LucideIcons.pencil),
              const SizedBox(height: 8),
              TextFormField(
                controller: _goalCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Περιγράψτε τον στόχο του πελάτη...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // ── Section 7: Financials ──────────────────────────────────
              _sectionTitle('Οικονομικά', LucideIcons.euro),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildField('Σύνολο (€)', _totalCtrl,
                          isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildField(
                      'Πληρωμένα (€)',
                      _paidCtrl,
                      isNumber: true,
                      maxLength: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _balanceCtrl,
                      readOnly: true,
                      decoration:
                          const InputDecoration(labelText: 'Υπόλοιπο (€)'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(labelText: 'Τρόπος Πληρωμής'),
                items: ['Μετρητά', 'Κάρτα', 'Iris']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) => setState(() => _paymentMethod = val!),
              ),
              const SizedBox(height: 28),

              // ── Save Button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(LucideIcons.save, size: 18),
                  label: const Text('Αποθήκευση'),
                ),
              ),

              // ── Timestamps ─────────────────────────────────────────────
              if (isEdit) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Ημ. Εγγραφής: ${_formatDate(widget.client!.createdAt)} — ${widget.client!.createdBy}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  'Τελευταία Επεξεργασία: ${_formatDate(widget.client!.lastEditedAt)} — ${widget.client!.lastEditedBy}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            )),
      ],
    );
  }

  Widget _buildDocumentChecklist() {
    // Collect all unique docs for selected services
    final Set<String> docs = {};
    for (final svc in _selectedServices) {
      docs.addAll(_kServiceDocs[svc] ?? []);
    }
    if (_hasCustomService) {
      docs.add('Σχετικά έγγραφα (Custom υπηρεσία)');
    }

    if (docs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: docs
            .map((doc) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.fileCheck,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                          child:
                              Text(doc, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool required = false,
    bool isNumber = false,
    bool isNumericString = false,
    bool obscure = false,
    int? maxLength,
    int? exactLength,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      maxLength: maxLength,
      keyboardType: keyboardType ??
          ((isNumber || isNumericString)
              ? TextInputType.number
              : TextInputType.text),
      inputFormatters: isNumericString
          ? [FilteringTextInputFormatter.digitsOnly]
          : isNumber
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : null,
      decoration: InputDecoration(
          labelText: label, suffixIcon: suffix, counterText: ''),
      validator: (val) {
        if (required && (val == null || val.isEmpty)) {
          return 'Υποχρεωτικό πεδίο';
        }
        if (exactLength != null &&
            val != null &&
            val.isNotEmpty &&
            val.length != exactLength) {
          return 'Απαιτούνται ακριβώς $exactLength ψηφία';
        }
        return null;
      },
    );
  }
}
