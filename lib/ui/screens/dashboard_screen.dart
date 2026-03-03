import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';
import '../../services/database_service.dart';
import '../../models/client.dart';
import '../../data/mock_data.dart';
import '../widgets/client_form.dart';
import 'login_screen.dart';

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

  /// Returns true if the logged-in user is 'admin'.
  /// Used to conditionally show the 5th Logs tab and load audit data.
  bool get _isAdmin => widget.user == 'admin';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _setWindowSize(); // expand window from login size to dashboard size
    _refreshClients(); // initial data load
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

  /// Fetches clients from SQLite (or runs a search if [_searchQuery] is set).
  ///
  /// On first launch with an empty DB, seeds [MockData] so the UI is not blank.
  /// Audit logs are only fetched when [_isAdmin] is true to avoid leaking data.
  Future<void> _refreshClients() async {
    setState(() => _isLoading = true);

    // Use search query if present, otherwise fetch all records
    var data = _searchQuery.isEmpty
        ? await _db.getAllClients()
        : await _db.searchClients(_searchQuery);

    // DEBUG: Seed mock data on a completely empty database (first-run only)
    if (data.isEmpty && _searchQuery.isEmpty) {
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

  /// Tab 1: Realtime search list.
  /// Each keystroke updates [_searchQuery] and triggers [_refreshClients].
  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(LucideIcons.search, size: 18),
              hintText: 'Αναζήτηση...',
              contentPadding: EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _refreshClients(); // re-query for each keystroke
              });
            },
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _clients.isEmpty
                  ? const Center(child: Text('Δεν βρέθηκαν πελάτες'))
                  : ListView.builder(
                      itemCount: _clients.length,
                      itemBuilder: (ctx, i) {
                        final c = _clients[i];
                        return ListTile(
                          leading: CircleAvatar(
                            // Show client's DB primary key as the avatar label
                            child: Text('#${c.id}',
                                style: const TextStyle(fontSize: 11)),
                          ),
                          title: Text(c.name),
                          subtitle: Text('${c.serviceType} - ${c.afm}'),
                          trailing: Text('${c.balance}€'),
                          onTap: () => _showForm(c), // open edit dialog
                        );
                      },
                    ),
        ),
      ],
    );
  }

  /// Tab 2: Full DataTable overview of all loaded clients.
  /// Balance is coloured red (> 0) or green (= 0).
  /// Clicking any row opens the edit [ClientForm] dialog.
  Widget _buildDashboardTab() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _clients.isEmpty
            ? const Center(child: Text('Δεν βρέθηκαν πελάτες'))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal, // handles wide tables
                child: SingleChildScrollView(
                  child: DataTable(
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Όνομα')),
                      DataColumn(label: Text('Υπηρεσία')),
                      DataColumn(label: Text('ΑΦΜ')),
                      DataColumn(label: Text('Τηλέφωνο')),
                      DataColumn(label: Text('Υπόλοιπο')),
                      DataColumn(label: Text('Κατάσταση')),
                    ],
                    rows: _clients
                        .map((c) => DataRow(
                              onSelectChanged: (_) => _showForm(c),
                              cells: [
                                DataCell(Text(c.id.toString())),
                                DataCell(Text(c.name)),
                                DataCell(Text(c.serviceType)),
                                DataCell(Text(c.afm)),
                                DataCell(Text(c.phone)),
                                // Red balance = money still owed; green = fully paid
                                DataCell(Text('${c.balance}€',
                                    style: TextStyle(
                                      color: c.balance > 0
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ))),
                                DataCell(Chip(
                                  label: Text(c.customerStatus,
                                      style: const TextStyle(fontSize: 12)),
                                  backgroundColor: c.customerStatus == 'Νέος'
                                      ? Colors.blue.withValues(alpha: 0.1)
                                      : Colors.green.withValues(alpha: 0.1),
                                )),
                              ],
                            ))
                        .toList(),
                  ),
                ),
              );
  }

  /// Tab 3: Placeholder for future settings UI.
  Widget _buildSettingsTab() {
    return const Center(child: Text('Ρυθμίσεις (Not implemented)'));
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
    if (_auditLogs.isEmpty) {
      return const Center(
          child: Text('Δεν υπάρχουν καταγεγραμμένες ενέργειες.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Ημ/νία')),
            DataColumn(label: Text('Χρήστης')),
            DataColumn(label: Text('Ενέργεια')),
            DataColumn(label: Text('ID Πελάτη')),
            DataColumn(label: Text('Λεπτομέρειες')),
          ],
          rows: _auditLogs.map((log) {
            // Parse ISO-8601 timestamp into a displayable string
            final ts = log['timestamp'] as String? ?? '';
            DateTime? dt;
            try {
              dt = DateTime.parse(ts);
            } catch (_) {
              // If timestamp is malformed, fall back to raw string
            }
            final formattedDate = dt != null
                ? '${dt.day.toString().padLeft(2, '0')}/'
                    '${dt.month.toString().padLeft(2, '0')}/'
                    '${dt.year} '
                    '${dt.hour.toString().padLeft(2, '0')}:'
                    '${dt.minute.toString().padLeft(2, '0')}'
                : ts;

            final action = log['action'] as String? ?? '';
            final isCreate =
                action == 'Create'; // green for create, orange for update

            return DataRow(cells: [
              DataCell(
                  Text(formattedDate, style: const TextStyle(fontSize: 12))),
              DataCell(Text(log['username'] as String? ?? '-')),
              DataCell(Chip(
                label: Text(action, style: const TextStyle(fontSize: 11)),
                backgroundColor: isCreate
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
              )),
              DataCell(Text((log['customer_id'] ?? '-').toString())),
              DataCell(
                SizedBox(
                  width: 280,
                  child: Text(
                    log['details'] as String? ?? '-',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
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
