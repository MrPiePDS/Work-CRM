import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_flutter/ui/widgets/client_form.dart';

void main() {
  Widget createTestableWidget() {
    return const MaterialApp(
      home: Scaffold(
        body: ClientForm(user: 'test_admin'),
      ),
    );
  }

  group('ClientForm Tests', () {
    testWidgets('Should render empty form correctly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget());

      expect(find.text('Νέος Πελάτης'), findsOneWidget);

      // Ensure basic fields are present
      expect(
          find.widgetWithText(TextFormField, 'Ονοματεπώνυμο'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Τηλέφωνο'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);

      // Since no services are selected, AMKA/AMA/AFM fields should be visible
      expect(find.widgetWithText(TextFormField, 'ΑΜΚΑ'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'ΑΜΑ'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'ΑΦΜ'), findsOneWidget);
    });

    testWidgets('Toggling AMKA/AMA service should hide their text fields',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget());

      // Verify the text fields are initially present
      expect(find.widgetWithText(TextFormField, 'ΑΜΚΑ'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'ΑΜΑ'), findsOneWidget);

      // Tap the checkbox for AMKA/AMA service
      await tester.tap(find.text('ΑΜΚΑ / ΑΜΑ (160€)'));
      await tester.pumpAndSettle(); // Allow UI to rebuild

      // Because the service is selected, the client doesn't have AMKA/AMA yet, so the fields should hide
      expect(find.widgetWithText(TextFormField, 'ΑΜΚΑ'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'ΑΜΑ'), findsNothing);
    });

    testWidgets('Toggling AFM service should hide AFM text field',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget());

      // Verify the text field is initially present
      expect(find.widgetWithText(TextFormField, 'ΑΦΜ'), findsOneWidget);

      // Tap the checkbox for AFM service
      await tester.tap(find.text('ΑΦΜ (50€)'));
      await tester.pumpAndSettle(); // Allow UI to rebuild

      // AFM field should hide
      expect(find.widgetWithText(TextFormField, 'ΑΦΜ'), findsNothing);
    });
  });
}
