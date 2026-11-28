import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../settings/app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _sectionTitle(BuildContext context, IconData icon, String title) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon, size: 20, color: theme.colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ))),
    ]);
  }

  Widget _themeTile(BuildContext context, {
    required ThemeMode value,
    required ThemeMode selectedMode,
    required IconData icon,
    required String label,
    required ValueChanged<ThemeMode> onSelected,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = value == selectedMode;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('settings-theme-${value.name}'),
          onTap: () => onSelected(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 25, color: selected ? foreground : scheme.primary),
                const SizedBox(height: 8),
                Text(label, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.25,
                    fontWeight: FontWeight.w600, color: foreground)),
                const SizedBox(height: 7),
                Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  size: 17, color: selected ? foreground : scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    String tr(String bn, String en) => AppText.of(context, bn, en);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        leadingWidth: 48,
        centerTitle: false,
        backgroundColor: dark ? const Color(0xFF36060D) : const Color(0xFF650D18),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        leading: IconButton(
          tooltip: tr('ফিরে যান', 'Back'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
        ),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .24)),
            ),
            child: const Icon(Icons.settings_outlined, size: 29, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(child: Text(tr('সেটিংস', 'Settings'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15.5,
              fontWeight: FontWeight.w500, height: 1.2))),
        ]),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
          children: [
            _sectionTitle(context, Icons.language_rounded, tr('ভাষা', 'Language')),
            const SizedBox(height: 10),
            ValueListenableBuilder<Locale>(
              valueListenable: settings.locale,
              builder: (context, locale, _) => SegmentedButton<String>(
                key: const ValueKey('settings-language-selector'),
                segments: const [
                  ButtonSegment(value: 'bn', label: Text('বাংলা')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {locale.languageCode == 'en' ? 'en' : 'bn'},
                onSelectionChanged: (values) {
                  if (values.isNotEmpty) settings.setLanguage(values.first);
                },
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                  visualDensity: VisualDensity.standard,
                  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(context, Icons.palette_outlined, tr('অ্যাপের থিম', 'App theme')),
            const SizedBox(height: 10),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: settings.themeMode,
              builder: (context, mode, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final tiles = [
                    _themeTile(context, value: ThemeMode.system, selectedMode: mode,
                      icon: Icons.devices_outlined, label: tr('সিস্টেম', 'System'),
                      onSelected: settings.setTheme),
                    _themeTile(context, value: ThemeMode.light, selectedMode: mode,
                      icon: Icons.light_mode_outlined, label: tr('লাইট', 'Light'),
                      onSelected: settings.setTheme),
                    _themeTile(context, value: ThemeMode.dark, selectedMode: mode,
                      icon: Icons.dark_mode_outlined, label: tr('ডার্ক', 'Dark'),
                      onSelected: settings.setTheme),
                  ];
                  final stacked = constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(12) > 20;
                  if (stacked) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (int i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        tiles[i],
                      ]]);
                  }
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (int i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: tiles[i]),
                    ],
                  ]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
