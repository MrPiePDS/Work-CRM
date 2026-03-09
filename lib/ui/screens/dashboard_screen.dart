import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;

import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../../services/migration_service.dart';
import '../../models/client.dart';
import '../../data/mock_data.dart';
import '../widgets/client_form.dart';
import 'login_screen.dart';
import '../../main.dart';
import '../../services/version_service.dart';

/// ─── DashboardScreen ────────────────────────────────────────────────────────
///
/// Main application screen shown after a successful login.
/// Contains a [TabBar] with up to 5 tabs:
///   0. Νέος πελάτης  – Inline [ClientForm] to add a new record
///   1. Αναζήτηση     – Live search through clients
///   2. Πίνακας       – Full DataTable of all clients
///   3. Ρυθμίσεις     – Placeholder (not yet implemented)
///   4. Αρχείο (Logs) – Visible to admin only; shows [_auditLogs]
///
/// State:
///   [_clients]    – The currently loaded/filtered list of [Client] objects.
///   [_auditLogs]  – Raw audit log rows (fetched only for admin).
///   [_isLoading]  – True while DB queries are in flight (shows spinner).
///   [_searchQuery]– Current text in the search box; drives [_refreshClients].
class DashboardScreen extends StatefulWidget {
  /// Username passed from [LoginScreen] after authentication.
  final String user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Services ───────────────────────────────────────────────────────────────
  final _db = DatabaseService(); // singleton DB access

  // ── State ──────────────────────────────────────────────────────────────────
  List<Client> _clients = [];
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _logsSearchQuery = '';

  // ── Update State ───────────────────────────────────────────────────────────
  bool _autoCheckUpdates = false;
  bool _isCheckingForUpdates = false;
  double _updateProgress = 0.0;
  final _versionService = VersionService();

  // ── Optimization Cache ────────────────────────────────────────────────────
  List<Client> _cachedFilteredClients = [];
  List<Map<String, dynamic>> _cachedFilteredAuditLogs = [];

  // ── Filter State ──────────────────────────────────────────────────────────
  String _filterStatus = 'Όλα';
  String _filterService = 'Όλα';
  String _filterPayment = 'Όλα';

  // ── Sorting State ─────────────────────────────────────────────────────────
  int? _sortColumnIndex;
  bool _sortAscending = true;

  static const _statusOptions = [
    'Όλα',
    'Νέος',
    'Σε επεξεργασία',
    'Αναμονή',
    'Ολοκληρωμένος',
    'Απορριφθείς'
  ];
  static const _serviceOptions = [
    'Όλα',
    'ΑΜΚΑ / ΑΜΑ',
    'Κλειδάριθμος',
    'Μεταβολή',
    'ΑΦΜ',
    'Εργασία',
    'Custom'
  ];
  static const _paymentOptions = ['Όλα', 'Μετρητά', 'Κάρτα', 'Iris'];

  /// Updates the cached filtered lists for clients and logs.
  /// This should be called whenever filter criteria or raw data change.
  void _applyFilters() {
    // 1. Filter Clients (Status, Service, Payment + Search Query)
    final clients = _clients.where((c) {
      // Dropdown filters
      if (_filterStatus != 'Όλα' && c.customerStatus != _filterStatus) {
        return false;
      }
      if (_filterService != 'Όλα' && !c.serviceType.contains(_filterService)) {
        return false;
      }
      if (_filterPayment != 'Όλα' && c.paymentMethod != _filterPayment) {
        return false;
      }

      // Search query filter (Local implementation)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = (c.id?.toString().contains(q) ?? false) ||
            c.name.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q) ||
            c.afm.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();

    // 2. Sort Clients
    if (_sortColumnIndex != null) {
      clients.sort((a, b) {
        int cmp = 0;
        switch (_sortColumnIndex) {
          case 0:
            cmp = (a.id ?? 0).compareTo(b.id ?? 0);
            break;
          case 1:
            cmp = a.name.compareTo(b.name);
            break;
          case 2:
            cmp = a.serviceType.compareTo(b.serviceType);
            break;
          case 3:
            cmp = a.afm.compareTo(b.afm);
            break;
          case 5:
            cmp = a.balance.compareTo(b.balance);
            break;
        }
        return _sortAscending ? cmp : -cmp;
      });
    }
    _cachedFilteredClients = clients;

    // 3. Filter Logs (Search Query + O(1) Lookups for cross-filter)
    // Using a map for O(1) lookups instead of O(N) searching inside the filter loop
    final clientMap = {for (var c in _clients) c.id.toString(): c};

    _cachedFilteredAuditLogs = _auditLogs.where((log) {
      // Search filter
      if (_logsSearchQuery.isNotEmpty) {
        final q = _logsSearchQuery.toLowerCase();
        final matchesQuery = (log['username']
                    ?.toString()
                    .toLowerCase()
                    .contains(q) ??
                false) ||
            (log['action']?.toString().toLowerCase().contains(q) ?? false) ||
            (log['details']?.toString().toLowerCase().contains(q) ?? false) ||
            (log['customer_id']?.toString().contains(q) ?? false);
        if (!matchesQuery) return false;
      }

      // Customer attribute filters (Cross-referencing logs with current client state)
      if (_filterStatus != 'Όλα' ||
          _filterService != 'Όλα' ||
          _filterPayment != 'Όλα') {
        final custId = log['customer_id']?.toString();
        final client = clientMap[custId];
        if (client == null) {
          return false;
        }

        if (_filterStatus != 'Όλα' && client.customerStatus != _filterStatus) {
          return false;
        }
        if (_filterService != 'Όλα' &&
            !client.serviceType.contains(_filterService)) {
          return false;
        }
        if (_filterPayment != 'Όλα' && client.paymentMethod != _filterPayment) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // Getters now return the cached (pre-sorted and pre-filtered) lists
  List<Client> get _filteredClients => _cachedFilteredClients;
  List<Map<String, dynamic>> get _filteredAuditLogs => _cachedFilteredAuditLogs;

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applyFilters(); // Re-apply sorting to the cache
    });
  }

  /// Returns true if the logged-in user is 'admin'.
  /// Used to conditionally show the 5th Logs tab and load audit data.
  bool get _isAdmin => widget.user == 'admin';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _setWindowSize(); // expand window from login size to dashboard size
    _loadUpdatePreference();
    _refreshClients(); // initial data load
  }

  Future<void> _loadUpdatePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoCheckUpdates =
          prefs.getBool('autoCheckUpdates') ?? true; // default true
    });
    if (_autoCheckUpdates) {
      _checkForUpdates(silent: true);
    }
  }

  Future<void> _checkForUpdates({bool silent = false}) async {
    if (_isCheckingForUpdates) return;
    setState(() => _isCheckingForUpdates = true);

    try {
      final hasUpdate = await _versionService.checkForUpdates();
      if (!mounted) return;

      if (hasUpdate) {
        _showUpdateDialog();
      } else if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Έχετε την τελευταία έκδοση!')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingForUpdates = false);
      }
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Νέα Ενημέρωση Διαθέσιμη'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Μια νέα έκδοση είναι διαθέσιμη. Θέλετε να την εγκαταστήσετε τώρα;'),
                  if (_updateProgress > 0) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _updateProgress),
                    const SizedBox(height: 8),
                    Text('${(_updateProgress * 100).toInt()}%'),
                  ],
                ],
              ),
              actions: _updateProgress > 0
                  ? [] // Hide buttons while downloading
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Αργότερα'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          setDialogState(() => _updateProgress = 0.01);
                          final navigator = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(context);

                          final success =
                              await _versionService.downloadAndInstallUpdate(
                            (progress, total) {
                              if (mounted) {
                                setDialogState(() {
                                  _updateProgress = progress / total;
                                });
                              }
                            },
                          );
                          if (!success && mounted) {
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text('Αποτυχία ενημέρωσης.')),
                            );
                          }
                        },
                        child: const Text('Ενημέρωση'),
                      ),
                    ],
            );
          },
        );
      },
    ).then((_) {
      if (mounted) setState(() => _updateProgress = 0.0);
    });
  }

  // ── Window Management ──────────────────────────────────────────────────────

  /// Expands the window to the full dashboard size (1200×750).
  /// Also raises the minimum so the user cannot shrink it below 900×600.
  Future<void> _setWindowSize() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setMinimumSize(const Size(900, 600));
      await windowManager.setSize(const Size(1200, 750));
      await windowManager.center();
    }
  }

  /// Shrinks the window back to login size, then navigates to [LoginScreen].
  /// Uses [pushReplacement] so pressing Back on the login screen doesn't
  /// return to the (now invalid) dashboard session.
  Future<void> _logout() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setMinimumSize(const Size(440, 460));
      await windowManager.setSize(const Size(440, 460));
      await windowManager.center();
    }
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ── Data Loading ───────────────────────────────────────────────────────────

  /// Fetches clients from SQLite.
  ///
  /// On first launch with an empty DB, seeds [MockData] so the UI is not blank.
  /// Audit logs are only fetched when [_isAdmin] is true to avoid leaking data.
  Future<void> _refreshClients() async {
    setState(() => _isLoading = true);

    // Fetch ALL records (search is now done locally for better performance)
    var data = await _db.getAllClients();

    // DEBUG: Seed mock data on a completely empty database (first-run only)
    if (data.isEmpty) {
      final mockData = MockData.getMockClients();
      for (final client in mockData) {
        await _db.insertClient(client);
      }
      data = await _db.getAllClients();
    }

    // Only admins can see the full audit trail
    var logs = _isAdmin ? await _db.getAuditLogs() : <Map<String, dynamic>>[];

    if (mounted) {
      setState(() {
        _clients = data;
        _auditLogs = logs;
        _applyFilters(); // Apply local filtering and populate cache
        _isLoading = false;
      });
    }
  }

  // ── Navigation Helpers ─────────────────────────────────────────────────────

  /// Opens a [ClientForm] dialog for creating (client == null) or editing.
  /// Refreshes the client list if the form was saved (result == true).
  void _showForm([Client? client]) async {
    final result = await showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ClientForm(client: client, user: widget.user, isDialog: true),
      ),
    );
    // result is true when ClientForm calls Navigator.pop(true) after a save
    if (result == true) _refreshClients();
  }

  Future<void> _updateTheme(ThemeMode mode) async {
    appThemeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    String modeString = 'system';
    if (mode == ThemeMode.light) modeString = 'light';
    if (mode == ThemeMode.dark) modeString = 'dark';
    await prefs.setString('themeMode', modeString);
    setState(() {}); // Rebuild UI to reflect the dropdown change
  }

  // ── Tab Builders ───────────────────────────────────────────────────────────

  /// Tab 0: Persistent [ClientForm] embedded as a tab (not a dialog).
  /// [onSaved] triggers a client list refresh so Tab 2 stays up-to-date.
  Widget _buildNewClientTab() {
    return SingleChildScrollView(
      child: Center(
        child: ClientForm(
          user: widget.user,
          isDialog: false,
          onSaved: () {
            _refreshClients();
          },
        ),
      ),
    );
  }

  /// Shared minimalistic filter row used in both Search and Table tabs.
  Widget _buildFilterRow({bool showClearButton = true}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _miniDropdown('Κατάσταση', _filterStatus, _statusOptions, (v) {
          setState(() {
            _filterStatus = v!;
            _applyFilters();
          });
        }),
        const SizedBox(width: 8),
        _miniDropdown('Υπηρεσία', _filterService, _serviceOptions, (v) {
          setState(() {
            _filterService = v!;
            _applyFilters();
          });
        }),
        const SizedBox(width: 8),
        _miniDropdown('Πληρωμή', _filterPayment, _paymentOptions, (v) {
          setState(() {
            _filterPayment = v!;
            _applyFilters();
          });
        }),
        if (showClearButton &&
            (_filterStatus != 'Όλα' ||
                _filterService != 'Όλα' ||
                _filterPayment != 'Όλα')) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => setState(() {
              _filterStatus = 'Όλα';
              _filterService = 'Όλα';
              _filterPayment = 'Όλα';
              _applyFilters();
            }),
            icon: const Icon(LucideIcons.x, size: 14),
            tooltip: 'Καθαρισμός',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ],
    );
  }

  /// Compact dropdown chip used in filter rows.
  Widget _miniDropdown(String label, String value, List<String> options,
      ValueChanged<String?> onChanged) {
    final isSelected = value != 'Όλα';
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      // Use smaller horizontal padding to make it more compact
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Theme(
        data: theme.copyWith(
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            iconSize: 16,
            borderRadius: BorderRadius.circular(16),
            elevation: 3,
            padding: const EdgeInsets.symmetric(vertical: 6),
            icon: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(LucideIcons.chevronDown,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.disabledColor),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            selectedItemBuilder: (BuildContext context) {
              return options.map<Widget>((String item) {
                return Container(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList();
            },
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  /// Tab 1: Realtime search list with filter dropdowns.
  Widget _buildSearchTab() {
    final filtered = _filteredClients;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(
              MediaQuery.of(context).size.width < 600 ? 8.0 : 16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    hintText: 'Αναζήτηση...',
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.04),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                    _sortColumnIndex ??= 0; // Default sort by ID
                    _applyFilters();
                  });
                },
                icon: Icon(
                  _sortAscending ? LucideIcons.arrowDown : LucideIcons.arrowUp,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: _sortAscending ? 'Φθίνουσα σειρά' : 'Αύξουσα σειρά',
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              _buildFilterRow(),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const Center(child: Text('Δεν βρέθηκαν πελάτες'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final c = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('#${c.id}',
                                style: const TextStyle(fontSize: 11)),
                          ),
                          title: Text(c.name),
                          subtitle: Text('${c.serviceType} - ${c.afm}'),
                          trailing: Text('${c.balance}€'),
                          onTap: () => _showForm(c),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  /// Tab 2: Full-width, scrollable DataTable with filters and export buttons.
  Widget _buildDashboardTab() {
    final filtered = _filteredClients;
    return Column(
      children: [
        // ── Minimalist Toolbar: Title, Filters, Export Buttons ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                'Λίστα Πελατών',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _exportToPdf(filtered),
                icon: const Icon(LucideIcons.fileText, size: 20),
                tooltip: 'Εξαγωγή σε PDF',
                color: Colors.red.shade700,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => _exportToExcel(filtered),
                icon: const Icon(LucideIcons.table, size: 20),
                tooltip: 'Εξαγωγή σε Excel',
                color: Colors.green.shade700,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // ── Table body ──
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const Center(child: Text('Δεν βρέθηκαν πελάτες'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Theme.of(context)
                                            .dividerColor
                                            .withValues(alpha: 0.1))),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  _buildSortableHeader('ID', 0, 1),
                                  _buildSortableHeader('Όνομα', 1, 3),
                                  _buildSortableHeader('Υπηρεσία', 2, 2),
                                  _buildSortableHeader('ΑΦΜ', 3, 2),
                                  _buildHeader('Τηλέφωνο', 2),
                                  _buildSortableHeader('Υπόλοιπο', 5, 2,
                                      numeric: true),
                                  _buildHeader('Κατάσταση', 2),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (ctx, i) {
                                  final c = filtered[i];
                                  return InkWell(
                                    onTap: () => _showForm(c),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                            bottom: BorderSide(
                                                color: Theme.of(context)
                                                    .dividerColor
                                                    .withValues(alpha: 0.05))),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                              flex: 1,
                                              child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 8),
                                                  child: Text(
                                                      c.id.toString(),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 13)))),
                                          Expanded(
                                              flex: 3,
                                              child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 8),
                                                  child: Text(
                                                      c.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight
                                                              .w500)))),
                                          Expanded(
                                              flex: 2,
                                              child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 8),
                                                  child: Text(
                                                      c.serviceType,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 13)))),
                                          Expanded(
                                              flex: 2,
                                              child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 8),
                                                  child: Text(
                                                      c.afm,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 13)))),
                                          Expanded(
                                              flex: 2,
                                              child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 8),
                                                  child: Text(
                                                      c.phone,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 13)))),
                                          Expanded(
                                              flex: 2,
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8),
                                                  child: Align(
                                                      alignment: Alignment
                                                          .centerRight,
                                                      child: Text(
                                                          '${c.balance}€',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                              fontSize: 13,
                                                              color: c.balance >
                                                                      0
                                                                  ? Colors.red
                                                                  : Colors
                                                                      .green,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold))))),
                                          Expanded(
                                              flex: 2,
                                              child: Padding(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8),
                                                  child: Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Chip(
                                                          label: Text(
                                                              c.customerStatus,
                                                              style: const TextStyle(
                                                                  fontSize:
                                                                      11)),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          backgroundColor: c.customerStatus ==
                                                                  'Νέος'
                                                              ? Colors.blue.withValues(
                                                                  alpha: 0.1)
                                                              : Colors.green.withValues(
                                                                  alpha: 0.1))))),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSortableHeader(String label, int columnIndex, int flex,
      {bool numeric = false}) {
    final isSorted = _sortColumnIndex == columnIndex;
    final theme = Theme.of(context);
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () {
          _onSort(columnIndex, isSorted ? !_sortAscending : true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface),
              ),
              if (isSorted) ...[
                const SizedBox(width: 4),
                Icon(
                  _sortAscending ? LucideIcons.arrowUp : LucideIcons.arrowDown,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }

  // ── Export Helpers ─────────────────────────────────────────────────────────

  Future<void> _exportToPdf(List<Client> clients) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Αποθήκευση PDF',
      fileName: 'clients_export.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (savePath == null) return;

    final bytes = await PdfService.generateClientListPdf(clients, savePath);
    await File(savePath).writeAsBytes(bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Το PDF εξήχθη επιτυχώς!')));
    }
  }

  Future<void> _exportToExcel(List<Client> clients) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Αποθήκευση Excel',
      fileName: 'clients_export.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (savePath == null) return;

    final excel = xl.Excel.createExcel();
    final sheet = excel['Πελάτες'];

    // Headers
    final headers = [
      'ID',
      'Όνομα',
      'Τηλέφωνο',
      'Email',
      'Υπηρεσία',
      'ΑΦΜ',
      'ΑΜΚΑ',
      'Κατάσταση',
      'Πληρωμή',
      'Σύνολο',
      'Πληρωμένο',
      'Υπόλοιπο'
    ];
    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = xl.TextCellValue(headers[i]);
    }

    // Data rows
    for (var r = 0; r < clients.length; r++) {
      final c = clients[r];
      final values = [
        c.id.toString(),
        c.name,
        c.phone,
        c.email,
        c.serviceType,
        c.afm,
        c.amka,
        c.customerStatus,
        c.paymentMethod,
        c.total.toStringAsFixed(2),
        c.paid.toStringAsFixed(2),
        c.balance.toStringAsFixed(2),
      ];
      for (var col = 0; col < values.length; col++) {
        sheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: col, rowIndex: r + 1))
            .value = xl.TextCellValue(values[col]);
      }
    }

    // Remove the default 'Sheet1' if it exists
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.save();
    if (bytes != null) {
      await File(savePath).writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Το Excel εξήχθη επιτυχώς!')));
      }
    }
  }

  /// Tab 3: Settings UI.
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildAppearanceSettings(),
        _buildUpdateSystemCard(),
        _buildChangePasswordCard(),
        if (_isAdmin) _buildAdminUserManagementCard(),
        if (_isAdmin) _buildDataManagementCard(),
      ],
    );
  }

  Widget _buildAppearanceSettings() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Εμφάνιση (Appearance)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.palette),
              title: const Text('Θέμα Εφαρμογής'),
              subtitle: const Text(
                  'Επιλέξτε ανάμεσα σε Φωτεινό, Σκοτεινό ή Σύστημα.'),
              trailing: DropdownButton<ThemeMode>(
                value: appThemeNotifier.value,
                items: const [
                  DropdownMenuItem(
                      value: ThemeMode.system, child: Text('Σύστημα')),
                  DropdownMenuItem(
                      value: ThemeMode.light, child: Text('Φωτεινό')),
                  DropdownMenuItem(
                      value: ThemeMode.dark, child: Text('Σκοτεινό')),
                ],
                onChanged: (val) {
                  if (val != null) _updateTheme(val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Settings Sub-Cards ─────────────────────────────────────────────────────

  Widget _buildUpdateSystemCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ενημερώσεις Εφαρμογής',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            SwitchListTile(
              title: const Text('Αυτόματος Έλεγχος'),
              subtitle:
                  const Text('Έλεγχος για νέες εκδόσεις κατά την εκκίνηση.'),
              value: _autoCheckUpdates,
              secondary: const Icon(LucideIcons.refreshCw),
              onChanged: (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('autoCheckUpdates', val);
                setState(() => _autoCheckUpdates = val);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.download),
              title: const Text('Έλεγχος Τώρα'),
              subtitle: const Text('Χειροκίνητος έλεγχος για ενημερώσεις.'),
              trailing: _isCheckingForUpdates
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ElevatedButton(
                      onPressed: () => _checkForUpdates(silent: false),
                      child: const Text('Έλεγχος'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ασφάλεια Λογαριασμού',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.lock),
              title: const Text('Αλλαγή Κωδικού'),
              subtitle: const Text(
                  'Ενημερώστε τον κωδικό πρόσβασης του λογαριασμού σας.'),
              trailing: ElevatedButton(
                onPressed: _changePasswordDialog,
                child: const Text('Αλλαγή'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminUserManagementCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Διαχείριση Χρηστών (Admin)',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _addUserDialog,
                  icon: const Icon(LucideIcons.userPlus, size: 16),
                  label: const Text('Νέος Χρήστης'),
                ),
              ],
            ),
            const Divider(),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _db.getAllUsers(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final users = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (ctx, i) {
                    final u = users[i];
                    return ListTile(
                      leading: const Icon(LucideIcons.user),
                      title: Text(u['username']),
                      subtitle: Text('Ρόλος: ${u['role']}'),
                      trailing: u['username'] == 'admin'
                          ? null
                          : IconButton(
                              icon: const Icon(LucideIcons.trash,
                                  color: Colors.red),
                              onPressed: () async {
                                await _db.deleteUser(u['username']);
                                setState(() {}); // Refresh list
                              },
                            ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Διαχείριση Δεδομένων & Αρχείων',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.save),
              title: const Text('Αντίγραφο Ασφαλείας (Backup)'),
              subtitle: const Text('Εξαγωγή της βάσης δεδομένων crm_data.db'),
              trailing: ElevatedButton(
                onPressed: _backupDatabase,
                child: const Text('Εξαγωγή'),
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.uploadCloud),
              title: const Text('Εισαγωγή από Excel'),
              subtitle: const Text(
                  'Μαζική προσθήκη πελατών από παλαιότερες εκδόσεις.'),
              trailing: ElevatedButton(
                onPressed: _importFromExcel,
                child: const Text('Εισαγωγή'),
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.folder),
              title: const Text('Φάκελος Αρχείων Πελατών'),
              subtitle: const Text(
                  'Επιλογή κεντρικού φακέλου αποθήκευσης (π.χ. Τοπικό Δίκτυο).'),
              trailing: ElevatedButton(
                onPressed: _selectCustomFolder,
                child: const Text('Αλλαγή'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backupDatabase() async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Επιλογή τοποθεσίας αποθήκευσης DB',
      fileName: 'crm_data_backup.db',
    );
    if (savePath == null) return;

    final dbPath = await _db.getDbPath();
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      await dbFile.copy(savePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Το Backup ολοκληρώθηκε επιτυχώς!')));
      }
    }
  }

  Future<void> _importFromExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result != null && result.files.single.path != null) {
      if (mounted) setState(() => _isLoading = true);
      try {
        final migration = MigrationService();
        await migration.importFromExcel(result.files.single.path!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Η εισαγωγή ολοκληρώθηκε!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Σφάλμα εισαγωγής.')));
        }
      } finally {
        _refreshClients();
      }
    }
  }

  Future<void> _selectCustomFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Επιλέξτε κεντρικό φάκελο',
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customBaseFolder', result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Ο κεντρικός φάκελος ορίστηκε σε: $result')));
      }
    }
  }

  void _changePasswordDialog() {
    final curPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Αλλαγή Κωδικού'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: curPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Τρέχων Κωδικός'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Νέος Κωδικός'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: const Text('Άκυρο'),
          ),
          ElevatedButton(
            onPressed: () async {
              final userData =
                  await _db.verifyUser(widget.user, curPassCtrl.text);
              if (!mounted) return;
              if (userData == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Ο τρέχων κωδικός είναι λάθος.')));
                return;
              }
              if (newPassCtrl.text.isEmpty) return;
              await _db.updatePassword(widget.user, newPassCtrl.text);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ο κωδικός άλλαξε επιτυχώς.')));
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Αποθήκευση'),
          )
        ],
      ),
    );
  }

  void _addUserDialog() {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Νέος Χρήστης'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(labelText: 'Όνομα Χρήστη'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Κωδικός'),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: const Text('Άκυρο'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = userCtrl.text.trim();
              if (user.isEmpty || passCtrl.text.isEmpty) return;
              await _db.createUser(user, passCtrl.text, 'user');
              if (!mounted) return;
              setState(() {}); // refresh Settings tab
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Δημιουργία'),
          )
        ],
      ),
    );
  }

  /// Tab 4 (admin-only): Full audit log table.
  ///
  /// Data source: [_auditLogs] (loaded in [_refreshClients] for admins).
  /// Each row represents one DB write (Create or Update) with:
  ///   timestamp, username, action type (colour-coded chip), customer_id, details.
  ///
  /// DEBUG TIP: If this tab is empty but you expect logs, verify:
  ///   1. widget.user == 'admin' (check [_isAdmin] getter)
  ///   2. audit_logs table has rows (open DB in a SQLite viewer)
  ///   3. DatabaseService.getAuditLogs() is being called without exception
  Widget _buildAuditLogsTab() {
    final filteredLogs = _filteredAuditLogs;

    return Column(
      children: [
        // ── Unified Search & Filter Toolbar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText:
                        'Αναζήτηση στα logs (χρήστης, ενέργεια, ID, κείμενο)...',
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.04),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _logsSearchQuery = val;
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterRow(),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // ── Logs List Body ──
        Expanded(
          child: _auditLogs.isEmpty
              ? const Center(
                  child: Text('Δεν υπάρχουν καταγεγραμμένες ενέργειες.'))
              : filteredLogs.isEmpty
                  ? const Center(
                      child: Text('Κανένα log δεν ταιριάζει με τα κριτήρια.'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Row
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: Theme.of(context)
                                        .dividerColor
                                        .withValues(alpha: 0.1))),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              _buildHeader('Ημ/νία', 2),
                              _buildHeader('Χρήστης', 2),
                              _buildHeader('Ενέργεια', 1),
                              _buildHeader('ID Πελάτη', 1),
                              _buildHeader('Λεπτομέρειες', 4),
                            ],
                          ),
                        ),
                        // List Body
                        Expanded(
                          child: ListView.builder(
                            itemCount: filteredLogs.length,
                            itemBuilder: (ctx, i) {
                              final log = filteredLogs[i];
                              final ts = log['timestamp'] as String? ?? '';
                              DateTime? dt;
                              try {
                                dt = DateTime.parse(ts);
                              } catch (_) {}
                              final formattedDate = dt != null
                                  ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                                  : ts;

                              final action = log['action'] as String? ?? '';
                              final isCreate = action == 'Create';

                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Theme.of(context)
                                              .dividerColor
                                              .withValues(alpha: 0.05))),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                        flex: 2,
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            child: Text(formattedDate,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12)))),
                                    Expanded(
                                        flex: 2,
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            child: Text(
                                                log['username'] as String? ??
                                                    '-',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12)))),
                                    Expanded(
                                        flex: 1,
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Chip(
                                                    label: Text(action,
                                                        style: const TextStyle(
                                                            fontSize: 11)),
                                                    padding: EdgeInsets.zero,
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    backgroundColor: isCreate
                                                        ? Colors.green
                                                            .withValues(
                                                                alpha: 0.15)
                                                        : Colors.orange
                                                            .withValues(
                                                                alpha:
                                                                    0.15))))),
                                    Expanded(
                                        flex: 1,
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            child: Text(
                                                (log['customer_id'] ?? '-')
                                                    .toString(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12)))),
                                    Expanded(
                                        flex: 4,
                                        child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            child: Text(
                                                log['details'] as String? ??
                                                    '-',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12)))),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTabController(
        // 5 tabs for admin, 4 for regular users (no Logs tab)
        length: _isAdmin ? 5 : 4,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // ── App Bar Row ─────────────────────────────────────────────
              Row(
                children: [
                  Text('Client Manager',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  Text('Συνδεδεμένος: ${widget.user}',
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 10),
                  // Manual refresh button (data is also auto-refreshed after saves)
                  IconButton(
                    icon: const Icon(LucideIcons.refreshCw),
                    onPressed: _refreshClients,
                    tooltip: 'Ανανέωση δεδομένων',
                  ),
                  // Logout: shrinks window → pushReplacement(LoginScreen)
                  IconButton(
                    icon: const Icon(LucideIcons.logOut),
                    onPressed: _logout,
                    tooltip: 'Αποσύνδεση',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TabBar(
                tabs: [
                  const Tab(text: 'Νέος πελάτης'),
                  const Tab(text: 'Αναζήτηση'),
                  const Tab(text: 'Πίνακας'),
                  const Tab(text: 'Ρυθμίσεις'),
                  if (_isAdmin) const Tab(text: 'Αρχείο (Logs)'),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildNewClientTab(), // Tab 0
                    _buildSearchTab(), // Tab 1
                    _buildDashboardTab(), // Tab 2
                    _buildSettingsTab(), // Tab 3
                    if (_isAdmin) _buildAuditLogsTab(), // Tab 4 (admin only)
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
