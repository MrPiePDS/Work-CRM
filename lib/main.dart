import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'utils/theme.dart';
import 'ui/screens/login_screen.dart';

/// Global notifier for the app's theme mode.
/// Can be accessed anywhere to change the theme: `appThemeNotifier.value = ThemeMode.dark;`
late ValueNotifier<ThemeMode> appThemeNotifier;

/// ─── Entry Point ────────────────────────────────────────────────────────────
///
/// main() initialises the window manager for desktop platforms and then
/// launches the Flutter widget tree.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('themeMode') ?? 'system';
  ThemeMode initialTheme = ThemeMode.system;
  if (savedTheme == 'light') initialTheme = ThemeMode.light;
  if (savedTheme == 'dark') initialTheme = ThemeMode.dark;

  appThemeNotifier = ValueNotifier<ThemeMode>(initialTheme);

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // NOTE: Initial size is login-sized.
    // The dashboard will override this when it loads.
    WindowOptions windowOptions = const WindowOptions(
      size: Size(440, 460),
      minimumSize: Size(440, 460),
      center: true,
      title: 'Client Manager',
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Client Manager',
          debugShowCheckedModeBanner:
              false, // hide the debug ribbon in dev builds
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: const LoginScreen(),
        );
      },
    );
  }
}
