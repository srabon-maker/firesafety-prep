import 'package:flutter/material.dart';
import '../settings/app_settings.dart';

/// Lightweight, finite entrance animation; no API or timer dependency.
class UiLoading extends StatelessWidget {
  const UiLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bars = Column(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 3; i++)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 12, decoration: BoxDecoration(color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              FractionallySizedBox(widthFactor: .65, child: Container(height: 10,
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)))),
            ])),
          ])),
    ]);
    return Semantics(label: AppText.of(context, 'লোড হচ্ছে','Loading'), liveRegion: true,
      child: MediaQuery.disableAnimationsOf(context) ? bars : TweenAnimationBuilder<double>(
        tween: Tween(begin: .45, end: 1), duration: const Duration(milliseconds: 300),
        builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
        child: bars,
      ));
  }
}
