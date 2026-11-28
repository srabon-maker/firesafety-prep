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
    final old = List.generate(100, (i) => Comment(id: i + 1,
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
    saved.complete(101);
    await tester.pumpAndSettle();
    expect(requested, 101);
    expect(changed, 1);
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    expect(find.text('New comment').hitTestable(), findsOneWidget);
    final scroll = tester.state<ScrollableState>(
      find.descendant(of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable)).first);
    expect(scroll.position.pixels, greaterThan(0));
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

  testWidgets('first comment remains visible when the keyboard viewport expands',
      (tester) async {
    final saved = Completer<int?>();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 720);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(home: CommentsPage(
      post: post, onChanged: () {},
      authorize: (_) async => true,
      submitComment: (_) => saved.future,
      loadComments: (id) async => id == null ? [] :
        [Comment(id: id, author: 'Me', text: 'First comment', isOwner: true)],
    )));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.enterText(field, 'First comment');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    saved.complete(1);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    expect(find.text('First comment').hitTestable(), findsOneWidget);
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
  });
}
