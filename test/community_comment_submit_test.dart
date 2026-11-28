import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/theme/app_theme.dart';
import 'package:fire_safety_job_prep/models/community_post.dart';
import 'package:fire_safety_job_prep/widgets/post_card.dart';

void main() {
  final post = CommunityPost(id: 42, author: 'Member', time: 'Now',
    text: 'Example post', comments: []);

  test('comment photo parsing remains compatible with old API responses', () {
    expect(Comment.fromJson({'author_photo':'https://example.com/avatar.png'}).authorPhoto,
      'https://example.com/avatar.png');
    expect(Comment.fromJson({}).authorPhoto, isNull);
    expect(Comment.fromJson({'author_photo':null}).authorPhoto, isNull);
  });

  for(final mode in [ThemeMode.dark, ThemeMode.light]) {
    testWidgets('Compact comment cards show photo and safe fallback in $mode', (tester) async {
      tester.view.devicePixelRatio=1;
      tester.view.physicalSize=const Size(360,800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
        theme:AppTheme.lightTheme,darkTheme:AppTheme.darkTheme,themeMode:mode,
        home:CommentsPage(post:post,onChanged:(){},loadComments:(_)async=>[
          Comment(id:1,author:'Photo member',text:'First message',
            authorPhoto:'https://example.com/avatar.png',isOwner:true),
          Comment(id:2,author:'Other member',text:'Second message'),
          Comment(id:3,author:'Invalid photo',text:'Third message',
            authorPhoto:'http://example.com/avatar.png'),
        ])));
      // Flutter's test HTTP client returns an error; the image errorBuilder
      // must render a fallback instead of throwing or breaking the card.
      await tester.pump();
      final avatar=find.byKey(const ValueKey('comment-avatar-1'));
      final noPhoto=find.byKey(const ValueKey('comment-avatar-2'));
      final invalid=find.byKey(const ValueKey('comment-avatar-3'));
      expect(tester.getSize(avatar),const Size(30,30));
      final image=find.descendant(of:avatar,matching:find.byType(Image));
      expect(image,findsOneWidget);
      expect((tester.widget<Image>(image).image as NetworkImage).url,'https://example.com/avatar.png');
      await tester.pumpAndSettle();
      for(final fallback in [avatar,noPhoto,invalid]){
        expect(find.descendant(of:fallback,matching:find.byIcon(Icons.person_rounded)),findsOneWidget);
      }
      final name=find.text('Photo member');
      final body=find.text('First message');
      expect(tester.widget<Text>(name).style?.fontSize,13);
      expect(tester.widget<Text>(name).style?.fontWeight,FontWeight.w500);
      expect(tester.widget<Text>(body).style?.fontSize,14);
      expect(tester.getTopLeft(body).dy-tester.getBottomLeft(name).dy,closeTo(4,.1));
      final card=find.byKey(const ValueKey('comment-1'));
      final surface=tester.widget<Container>(card);
      expect(surface.padding,const EdgeInsets.all(10));
      expect((surface.decoration as BoxDecoration).borderRadius,BorderRadius.circular(12));
      expect(surface.margin,const EdgeInsets.only(bottom:6));
      final header=tester.widget<AppBar>(find.byType(AppBar));
      expect(header.toolbarHeight,68);
      expect(tester.getSize(find.byKey(const ValueKey('comments-header-icon'))),const Size(40,40));
      expect(tester.getSize(find.byKey(const ValueKey('comments-header-divider'))),const Size(1,42));
      final title=tester.widget<Text>(find.byKey(const ValueKey('comments-header-title')));
      expect(title.style?.fontSize,15.5);
      await tester.tap(find.descendant(of:card,matching:find.byType(PopupMenuButton<String>)));
      await tester.pumpAndSettle();
      expect(find.text('Delete comment'),findsOneWidget);
      expect(find.text('Report comment'),findsNothing);
      await tester.tapAt(const Offset(5,5));
      await tester.pumpAndSettle();
      final other=find.byKey(const ValueKey('comment-2'));
      await tester.tap(find.descendant(of:other,matching:find.byType(PopupMenuButton<String>)));
      await tester.pumpAndSettle();
      expect(find.text('Report comment'),findsOneWidget);
      expect(find.text('Delete comment'),findsNothing);
      expect(tester.takeException(),isNull);
    });
  }

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
