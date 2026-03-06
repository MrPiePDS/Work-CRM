import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_flutter/ui/screens/login_screen.dart';
import 'package:crm_flutter/ui/screens/dashboard_screen.dart';

void main() {
  setUpAll(() {
    // Mock the window_manager method channel to avoid MissingPluginException and TypeErrors
    const MethodChannel channel = MethodChannel('window_manager');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getSize' || methodCall.method == 'getBounds') {
        return {'x': 0.0, 'y': 0.0, 'width': 1920.0, 'height': 1080.0};
      }
      return true;
    });

    // Ignore RenderFlex overflow errors in tests just in case
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return; // Ignore
      }
      FlutterError.presentError(details);
    };
  });

  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
      theme: ThemeData.light(),
    );
  }

  group('LoginScreen Tests', () {
    testWidgets('Should display login UI elements correctly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget(const LoginScreen()));

      // Verify that the title is "Σύνδεση"
      expect(find.text('Σύνδεση').first, findsOneWidget);

      // Verify the TextFields are present
      expect(find.byType(TextField), findsNWidgets(2));

      // Verify login button is present
      expect(find.widgetWithText(ElevatedButton, 'Σύνδεση'), findsOneWidget);

      // Verify change password button is present
      expect(find.widgetWithText(ElevatedButton, 'Αλλαγή κωδικού admin'),
          findsOneWidget);
    });

    testWidgets('Should show error if fields are empty',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget(const LoginScreen()));

      // Tap on login button without entering credentials
      await tester.tap(find.widgetWithText(ElevatedButton, 'Σύνδεση'));
      await tester.pumpAndSettle();

      // Verify SnackBar error message
      expect(find.text('Παρακαλώ συμπληρώστε όλα τα πεδία'), findsOneWidget);
    });

    testWidgets('Should show error on wrong credentials',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget(const LoginScreen()));

      // Enter wrong user & pass
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'wronguser');
      await tester.enterText(textFields.last, 'wrongpass');

      // Tap login
      await tester.tap(find.widgetWithText(ElevatedButton, 'Σύνδεση'));
      await tester
          .pump(const Duration(seconds: 1)); // Give SnackBar time to show up

      // Verify SnackBar error message
      expect(find.text('Λάθος όνομα χρήστη ή κωδικός'), findsOneWidget);
    });

    testWidgets('Should navigate to Dashboard on correct credentials',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget(const LoginScreen()));

      // Enter correct admin & 1234
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'admin');
      await tester.enterText(textFields.last, '1234');

      // Tap login
      await tester.tap(find.widgetWithText(ElevatedButton, 'Σύνδεση'));
      await tester.pumpAndSettle();

      // Ensure DashboardScreen appears and we moved forward
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
