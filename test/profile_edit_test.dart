import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/screens/edit_profile_page.dart';

void main() {
  testWidgets('Profile editor preloads user fields and locks Google email',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EditProfilePage(user: {
        'full_name': 'Test User',
        'email': 'test@example.com',
        'mobile_number': '01712345678',
        'current_status': 'Student',
      }),
    ));

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    final emailFormField = find.byWidgetPredicate(
      (widget) => widget is TextFormField &&
          widget.initialValue == 'test@example.com',
    );
    expect(emailFormField, findsOneWidget);
    final emailTextField = tester.widget<TextField>(
      find.descendant(
        of: emailFormField,
        matching: find.byType(TextField),
      ),
    );
    expect(emailTextField.readOnly, isTrue);
  });

  testWidgets('Cannot submit an empty required name or phone',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EditProfilePage(user: {
        'full_name': '',
        'email': 'test@example.com',
        'mobile_number': '',
        'current_status': 'Student',
      }),
    ));

    // The save action is below the viewport, but the full form must remain
    // mounted so validation also checks required fields above the viewport.
    final save = find.text('Save changes');
    expect(save, findsOneWidget);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('This field is required.'), findsNWidgets(2));
  });
}
