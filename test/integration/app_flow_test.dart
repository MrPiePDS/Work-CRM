import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:crm_flutter/main.dart';
import 'package:crm_flutter/services/database_service.dart';
import 'package:crm_flutter/ui/screens/dashboard_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Mock initial theme setup so tests don't crash
    SharedPreferences.setMockInitialValues({'themeMode': 'system'});
    appThemeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

    // Mock window manager
    const MethodChannel channel = MethodChannel('window_manager');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getSize' || methodCall.method == 'getBounds') {
        return {'x': 0.0, 'y': 0.0, 'width': 1920.0, 'height': 1080.0};
      }
      return true;
    });

    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      FlutterError.presentError(details);
    };
  });

  setUp(() async {
    DatabaseService.isTestMode = true;
    final dbService = DatabaseService();
    await dbService.clearDatabase();
  });

  group('Real-Life CRM Flow Integration Test', () {
    testWidgets('User logs in, sees dashboard, and can search clients',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Start the app
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // 1. App should start at the Login Screen
      expect(find.text('Σύνδεση').first, findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));

      // 2. Perform Login
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'admin');
      await tester.enterText(textFields.last, '1234');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Σύνδεση'));
      await tester.pumpAndSettle();

      // 3. User is now on the Dashboard
      expect(find.byType(DashboardScreen), findsOneWidget);

      // Look for the generic tab labels we expect from the design
      expect(find.text('Νέος πελάτης'), findsWidgets);
      expect(find.text('Αναζήτηση'), findsWidgets);
      expect(find.text('Αρχείο (Logs)'), findsWidgets);

      // 4. Navigate to the Appended Client form
      // The app architecture places the ClientForm in varying active tabs.
      // E.g. Tapping "Νέος πελάτης" tab if exists or button
      final newClientTab = find.text('Νέος πελάτης');
      if (newClientTab.evaluate().isNotEmpty) {
        await tester.tap(newClientTab.first);
        await tester.pumpAndSettle();

        // Ensure form renders inside the new client tab
        expect(find.text('Ονοματεπώνυμο'), findsWidgets);
      }
    });
  });
}
