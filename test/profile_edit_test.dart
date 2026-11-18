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
    final emailField = tester.widget<TextFormField>(
      find.byWidgetPredicate(
        (widget) => widget is TextFormField &&
            widget.initialValue == 'test@example.com',
      ),
    );
    expect(emailField.readOnly, isTrue);
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

    final save = find.text('Save changes');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(find.text('This field is required.'), findsNWidgets(2));
  });
}
