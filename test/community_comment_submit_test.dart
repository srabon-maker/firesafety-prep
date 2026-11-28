import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/community_post.dart';
import 'package:fire_safety_job_prep/widgets/post_card.dart';

void main() {
  final post = CommunityPost(id: 42, author: 'Member', time: 'Now',
    text: 'Example post', comments: []);

  testWidgets('submit hides keyboard, locks double taps and reveals returned comment',
      (tester) async {
    final saved = Completer<int?>();
    final old = List.generate(20, (i) => Comment(id: i + 1,
      author: 'Member', text: 'Old comment $i'));
    int sends = 0, changed = 0;
    int? requested;
    await tester.pumpWidget(MaterialApp(home: CommentsPage(
      post: post, onChanged: () => changed++,
      authorize: (_) async => true,
      submitComment: (_) { sends++; return saved.future; },
      loadComments: (id) async {
        requested = id;
        return id == null ? old : [...old,
          Comment(id: id, author: 'Me', text: 'New comment', isOwner: true)];
      },
    )));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.enterText(field, 'New comment');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
    expect(tester.widget<TextField>(field).readOnly, isTrue);
    tester.widget<TextField>(field).onSubmitted!('New comment');
    expect(sends, 1);
    saved.complete(99);
    await tester.pumpAndSettle();
    expect(requested, 99);
    expect(changed, 1);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(find.text('New comment').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed send retains draft and unlocks the composer', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CommentsPage(
      post: post, onChanged: () {},
      authorize: (_) async => true,
      loadComments: (_) async => [],
      submitComment: (_) async => throw Exception('Network failed'),
    )));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.enterText(field, 'Keep this draft');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, 'Keep this draft');
    expect(tester.widget<TextField>(field).readOnly, isFalse);
    expect(find.text('Network failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
