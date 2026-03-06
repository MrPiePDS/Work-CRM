import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../services/database_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setWindowSize();
  }

  Future<void> _setWindowSize() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.setSize(const Size(440, 260));
      await windowManager.center();
    }
  }

  void _login() async {
    final user = _userController.text.trim();
    final pass = _passController.text;

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Παρακαλώ συμπληρώστε όλα τα πεδία')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final db = DatabaseService();
    final userData = await db.verifyUser(user, pass);

    if (userData != null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DashboardScreen(user: user)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Λάθος όνομα χρήστη ή κωδικός')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // The password change functionality is now securely handled inside the app's Settings Tab.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(16), // root margins 16, 16, 16, 16
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              // spacing 12 translates to SizedBox(height: 12) between children
              children: [
                Text('Σύνδεση', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                const Text(
                  'Προεπιλογή: admin / 1234 (άλλαξε το μετά τη σύνδεση)',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(14), // card margins 14, 14, 14, 14
                    child: Column(
                      children: [
                        TextField(
                          controller: _userController,
                          decoration:
                              const InputDecoration(labelText: 'Όνομα χρήστη'),
                        ),
                        const SizedBox(height: 10), // card spacing 10
                        TextField(
                          controller: _passController,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Κωδικός'),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Text('Σύνδεση'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
