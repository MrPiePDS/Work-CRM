import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'utils/theme.dart';
import 'ui/screens/login_screen.dart';

/// ─── Entry Point ────────────────────────────────────────────────────────────
///
/// main() initialises the window manager for desktop platforms and then
/// launches the Flutter widget tree.
///
/// Window sizing strategy:
///   • App starts at 440×460 (login-sized, small).
///   • DashboardScreen._setWindowSize() resizes to 1200×750 after login.
///   • DashboardScreen._logout() resizes back to 440×460 on logout.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // NOTE: Initial size is login-sized.
    // The dashboard will override this when it loads.
    WindowOptions windowOptions = const WindowOptions(
      size: Size(440, 460),
      minimumSize: Size(440, 460),
      center: true,
      title: 'Client Manager v1.1.0a',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MyApp());
}

/// Root widget. Sets up MaterialApp with light/dark theme and points
/// the initial route to [LoginScreen].
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Client Manager v1.1.0a',
      debugShowCheckedModeBanner: false, // hide the debug ribbon in dev builds
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // follows the OS light/dark preference
      home: const LoginScreen(),
    );
  }
}
