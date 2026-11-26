import 'package:flutter/material.dart';
import '../settings/app_settings.dart';

/// Shared, theme-aware presentation. No data fetching or business logic.
class FsFeatureCard extends StatelessWidget {
  const FsFeatureCard({super.key, required this.icon, required this.title,
    required this.subtitle, this.onTap, this.vertical = false});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final symbol = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, size: 26, color: c.onPrimaryContainer),
    );
    final description = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
    ]);
    return Card(
      child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(16),
        child: vertical
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [symbol, const SizedBox(height: 12), description,
              if (onTap != null) Align(alignment: AlignmentDirectional.centerEnd, child: Icon(Icons.arrow_forward_rounded, color: c.primary))])
          : Row(children: [symbol, const SizedBox(width: 12), Expanded(child: description),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: c.primary)]),
      )),
    );
  }
}

/// A finite entrance animation avoids endless test settling and honours reduced motion.
class FsLoadingCards extends StatelessWidget {
  const FsLoadingCards({super.key, this.count = 3});
  final int count;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget bar(double width) => FractionallySizedBox(widthFactor: width, alignment: AlignmentDirectional.centerStart,
      child: Container(height: 10, decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(8))));
    return Semantics(label: AppText.of(context, 'লোড হচ্ছে','Loading'), child: ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .55, end: 1),
        duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
        builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
        child: LayoutBuilder(builder: (context, constraints) {
          final visible = constraints.hasBoundedHeight ? (constraints.maxHeight / 70).floor().clamp(0, count).toInt() : count;
          if (visible == 0) return const LinearProgressIndicator();
          return Column(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 0; i < visible; i++) Card(child: Padding(padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(10))),
              const SizedBox(width: 12), Expanded(child: Column(children: [bar(.85), const SizedBox(height: 8), bar(.55)])),
            ]))),
        ]); }),
      ),
    ));
  }
}

class FsStatusCard extends StatelessWidget {
  const FsStatusCard({super.key, required this.icon, required this.message, this.onRetry});
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 8), Text(message, textAlign: TextAlign.center),
      if (onRetry != null) TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded),
        label: Text(AppText.of(context, 'আবার চেষ্টা করুন','Try again'))),
    ])));
}
