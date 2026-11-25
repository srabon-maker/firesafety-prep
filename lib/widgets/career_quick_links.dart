import 'package:flutter/material.dart';
import '../settings/app_settings.dart';

class CareerQuickLinks extends StatelessWidget {
  const CareerQuickLinks({super.key, required this.onOpen});
  final ValueChanged<String> onOpen;

  static const items = [
    ('mock', 'মক ইন্টারভিউ', 'Mock Interview', Icons.forum_outlined, Color(0xFFE5EEFF)),
    ('courses', 'ট্রেনিং ও কোর্স', 'Training & Courses', Icons.school_outlined, Color(0xFFE5F4E8)),
    ('directory', 'প্রফেশনাল ডিরেক্টরি', 'Professional Directory', Icons.groups_outlined, Color(0xFFF3E8FF)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(AppText.of(context, 'ক্যারিয়ার ডেভেলপমেন্ট', 'Career Development'),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final item in items)
                Expanded(child: InkWell(
                  key: ValueKey('career-' + item.$1),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onOpen(item.$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(color: item.$5, borderRadius: BorderRadius.circular(14)),
                        child: Icon(item.$4, color: const Color(0xFF650D18), size: 23),
                      ),
                      const SizedBox(height: 5),
                      Text(AppText.of(context, item.$2, item.$3),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )),
            ]),
          ]),
        ),
      ),
    );
  }
}
