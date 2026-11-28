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
