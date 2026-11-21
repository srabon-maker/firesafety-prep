import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/models/marketplace_item.dart';
import 'package:fire_safety_job_prep/widgets/marketplace_catalog_card.dart';

void main() {
  Widget cardHost(
    MarketplaceItem item, {
    VoidCallback? onDetails,
    VoidCallback? onAction,
  }) {
    return MaterialApp(
      // Marketplace tests use Bengali labels.
      locale: const Locale('bn'),
      supportedLocales: const [
        Locale('bn'),
        Locale('en'),
      ],
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 176,
            height: 346,
            child: MarketplaceCatalogCard(
              item: item,
              onDetails: onDetails ?? () {},
              onAction: onAction ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'product card shows API discount and in-stock cart action',
    (tester) async {
      var added = false;

      final item = MarketplaceItem(
        id: '1',
        name: 'Fire Extinguisher',
        category: 'Safety Equipment',
        description: '',
        isService: false,
        price: 1200,
        comparePrice: 1500,
        stock: 5,
        isFeatured: true,
      );

      await tester.pumpWidget(
        cardHost(item, onAction: () => added = true),
      );

      expect(find.text('-20%'), findsOneWidget);
      expect(find.text('ফিচার্ড'), findsOneWidget);
      expect(find.text('৳1200'), findsOneWidget);
      expect(find.text('৳1500'), findsOneWidget);

      await tester.tap(find.byTooltip('কার্টে যোগ করুন'));

      expect(added, isTrue);
    },
  );

  testWidgets(
    'unusually high discount percentage is not advertised',
    (tester) async {
      final item = MarketplaceItem(
        id: '9',
        name: 'Fire Extinguisher',
        category: 'Safety Equipment',
        description: 'Portable fire extinguisher',
        isService: false,
        price: 1222,
        comparePrice: 100000,
        stock: 10,
      );

      await tester.pumpWidget(cardHost(item));

      expect(find.text('-99%'), findsNothing);
      expect(find.text('৳1222'), findsOneWidget);
      expect(find.text('৳100000'), findsNothing);
    },
  );

  testWidgets(
    'out-of-stock card routes to details, not cart',
    (tester) async {
      var details = false;
      var added = false;

      final item = MarketplaceItem(
        id: '2',
        name: 'Fire Helmet',
        category: '',
        description: '',
        isService: false,
        price: 400,
        stock: 0,
      );

      await tester.pumpWidget(
        cardHost(
          item,
          onDetails: () => details = true,
          onAction: () => added = true,
        ),
      );

      expect(find.text('স্টকে নেই'), findsOneWidget);

      await tester.tap(find.byTooltip('বিস্তারিত দেখুন'));

      expect(details, isTrue);
      expect(added, isFalse);
    },
  );

  testWidgets(
    'service card shows booking action without product discount',
    (tester) async {
      var booked = false;

      final item = MarketplaceItem(
        id: '3',
        name: 'Fire Safety Inspection',
        category: 'Inspection',
        description: '',
        isService: true,
        pricingType: 'starting',
        price: 2500,
        isFeatured: true,
      );

      await tester.pumpWidget(
        cardHost(item, onAction: () => booked = true),
      );

      expect(find.text('শুরু ৳2500'), findsOneWidget);
      expect(find.byTooltip('সার্ভিস বুকিং করুন'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);

      await tester.tap(find.byTooltip('সার্ভিস বুকিং করুন'));

      expect(booked, isTrue);
    },
  );
}
