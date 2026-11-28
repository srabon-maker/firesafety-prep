import 'dart:async';

import 'package:fire_safety_job_prep/models/marketplace_category.dart';
import 'package:fire_safety_job_prep/models/marketplace_engagement.dart';
import 'package:fire_safety_job_prep/models/marketplace_item.dart';
import 'package:fire_safety_job_prep/screens/marketplace_page.dart';
import 'package:fire_safety_job_prep/services/marketplace_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const product = MarketplaceItem(id: '1', name: 'Sample extinguisher',
    category: '', description: '', isService: false, price: 100, stock: 2);

Widget host({
  required bool active,
  required ValueNotifier<int> session,
  required Future<List<MarketplaceItem>> Function(bool) catalog,
  Future<int> Function()? cart,
}) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: const [Locale('bn'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: MarketplacePage(
    active: active, sessionChanges: session, loadCatalog: catalog,
    loadCategories: (_) async => <MarketplaceCategory>[],
    loadEngagement: () async => const MarketplaceEngagement({}, []),
    loadCartCount: cart ?? () async => 0,
  ),
);

void main() {
  test('Public read retries one transient error and succeeds', () async {
    var calls = 0;
    final result = await MarketplaceApiService.retryPublicRead(() async {
      if (++calls == 1) throw TimeoutException('offline');
      return 'ok';
    }, delay: Duration.zero);
    expect(result, 'ok');
    expect(calls, 2);
  });

  test('Public read retries at most once; invalid data is never retried', () async {
    var calls = 0;
    await expectLater(MarketplaceApiService.retryPublicRead(() async {
      calls++;
      throw http.ClientException('offline');
    }, delay: Duration.zero), throwsA(isA<http.ClientException>()));
    expect(calls, 2);
    calls = 0;
    await expectLater(MarketplaceApiService.retryPublicRead(() async {
      calls++;
      throw const FormatException('invalid');
    }, delay: Duration.zero), throwsFormatException);
    expect(calls, 1);
  });

  testWidgets('A failed initial catalog reloads automatically when Shop reopens',
      (tester) async {
    final session = ValueNotifier(0);
    var reads = 0;
    Future<List<MarketplaceItem>> catalog(bool _) async {
      if (++reads == 1) throw Exception('temporary unavailable');
      return [product];
    }
    Future<void> show(bool active) async {
      await tester.pumpWidget(host(active: active, session: session, catalog: catalog));
      await tester.pumpAndSettle();
    }
    await show(true);
    expect(find.text('Try again'), findsOneWidget);
    await show(false);
    expect(reads, 1);
    await show(true);
    expect(reads, 2);
    expect(find.text(product.name), findsOneWidget);
    await show(false);
    await show(true);
    expect(reads, 2); // Fresh public cache needs no new request.
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login refresh shares pending requests and keeps successful cards',
      (tester) async {
    final session = ValueNotifier(0);
    final first = Completer<List<MarketplaceItem>>();
    final next = Completer<List<MarketplaceItem>>();
    var reads = 0;
    Future<List<MarketplaceItem>> catalog(bool _) =>
        ++reads == 1 ? first.future : next.future;
    await tester.pumpWidget(host(active: true, session: session, catalog: catalog));
    await tester.pump();
    session.value++;
    await tester.pump();
    expect(reads, 1);
    first.complete([product]);
    await tester.pumpAndSettle();
    expect(find.text(product.name), findsOneWidget);
    session.value++;
    await tester.pump();
    expect(reads, 2);
    expect(find.text(product.name), findsOneWidget);
    session.value++;
    await tester.pump();
    expect(reads, 2);
    next.complete([product]);
    await tester.pumpAndSettle();
    expect(find.text(product.name), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login while Shop is hidden triggers fresh catalog and cart on return',
      (tester) async {
    final session = ValueNotifier(0);
    var reads = 0;
    var count = 0;
    Future<List<MarketplaceItem>> catalog(bool _) async {
      reads++;
      return [product];
    }
    Future<void> show(bool active) async {
      await tester.pumpWidget(host(active: active, session: session,
        catalog: catalog, cart: () async => count));
      await tester.pumpAndSettle();
    }
    await show(true);
    await show(false);
    count = 4;
    session.value++;
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    await show(true);
    expect(reads, 2);
    expect(find.text(product.name), findsOneWidget);
    expect((tester.widget<Badge>(find.byType(Badge)).label as Text).data, '4');
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cart count badge is red, anchored to icon and reflects quantity changes',
      (tester) async {
    final session = ValueNotifier(0);
    var count = 0;
    Future<void> show(bool active) async {
      await tester.pumpWidget(host(active: active, session: session,
        catalog: (_) async => [product], cart: () async => count));
      await tester.pumpAndSettle();
    }
    final badgeFinder = find.byKey(const ValueKey('market-cart-count-badge'));
    final iconFinder = find.byKey(const ValueKey('market-cart-icon'));
    Badge badge() => tester.widget<Badge>(badgeFinder);
    await show(true);
    expect(badge().isLabelVisible, isFalse);
    count = 9;
    await show(false);
    await show(true);
    expect(badge().isLabelVisible, isTrue);
    expect(badge().backgroundColor, const Color(0xFFD92D20));
    expect(badge().textColor, Colors.white);
    expect(badge().child!.key, const ValueKey('market-cart-icon'));
    final label = find.descendant(of: badgeFinder, matching: find.text('9'));
    expect(label, findsOneWidget);
    expect(tester.getCenter(label).dx, greaterThan(tester.getCenter(iconFinder).dx));
    expect(tester.getCenter(label).dy, lessThan(tester.getCenter(iconFinder).dy));
    expect(find.byTooltip('Cart'), findsOneWidget);
    final header = find.byType(AppBar);
    expect(find.descendant(of: header, matching: find.text('Orders')), findsNothing);
    expect(find.descendant(of: header, matching: find.text('Cart')), findsNothing);
    final orders = find.byTooltip('Orders & booking history');
    final cart = find.byTooltip('Cart');
    expect(orders, findsOneWidget);
    expect(tester.getSize(orders), const Size(48, 54));
    expect(tester.getSize(cart), const Size(48, 54));
    expect(tester.getCenter(find.byIcon(Icons.receipt_long_outlined)).dy,
      closeTo(tester.getCenter(iconFinder).dy, .01));
    expect(tester.getCenter(iconFinder).dy, closeTo(tester.getCenter(cart).dy, .01));
    count = 12;
    await show(false);
    await show(true);
    expect((badge().label as Text).data, '12');
    count = 124;
    await show(false);
    await show(true);
    expect((badge().label as Text).data, '99+');
    expect((badge().label as Text).semanticsLabel, '124 items in cart');
    count = 0;
    await show(false);
    await show(true);
    expect(badge().isLabelVisible, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Session change clears badge and rejects late previous-account count',
      (tester) async {
    final session = ValueNotifier(0);
    final old = Completer<int>();
    var cartReads = 0;
    Future<int> cart() {
      switch (++cartReads) {
        case 1: return Future.value(3);
        case 2: return old.future;
        default: return Future.value(0);
      }
    }
    await tester.pumpWidget(host(active: true, session: session,
      catalog: (_) async => [product], cart: cart));
    await tester.pumpAndSettle();
    Badge badge() => tester.widget<Badge>(find.byType(Badge));
    expect(badge().isLabelVisible, isTrue);
    expect((badge().label as Text).data, '3');
    session.value++;
    await tester.pumpAndSettle();
    expect(badge().isLabelVisible, isFalse);
    session.value++;
    await tester.pumpAndSettle();
    old.complete(7);
    await tester.pumpAndSettle();
    expect(badge().isLabelVisible, isFalse);
    expect((badge().label as Text).data, '0');
    expect(cartReads, 3);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    expect(tester.takeException(), isNull);
  });
}
