import 'package:flutter/material.dart';
import '../settings/app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    String tr(String bn, String en) => AppText.of(context, bn, en);
    return Scaffold(
      appBar: AppBar(title: Text(tr('সেটিংস', 'Settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('ভাষা নির্বাচন', 'Language'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ValueListenableBuilder<Locale>(
            valueListenable: settings.locale,
            builder: (context, locale, _) => Card(
              child: Column(children: [
                RadioListTile<String>(
                  title: const Text('বাংলা'),
                  value: 'bn',
                  groupValue: locale.languageCode,
                  onChanged: (value) {
                    if (value != null) settings.setLanguage(value);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('English'),
                  value: 'en',
                  groupValue: locale.languageCode,
                  onChanged: (value) {
                    if (value != null) settings.setLanguage(value);
                  },
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Text(tr('অ্যাপের থিম', 'Appearance'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: settings.themeMode,
            builder: (context, mode, _) => Card(
              child: Column(children: [
                RadioListTile<ThemeMode>(
                  title: Text(tr('সিস্টেম অনুযায়ী', 'Follow system')),
                  value: ThemeMode.system,
                  groupValue: mode,
                  onChanged: (value) {
                    if (value != null) settings.setTheme(value);
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: Text(tr('লাইট মোড', 'Light mode')),
                  value: ThemeMode.light,
                  groupValue: mode,
                  onChanged: (value) {
                    if (value != null) settings.setTheme(value);
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: Text(tr('ডার্ক মোড', 'Dark mode')),
                  value: ThemeMode.dark,
                  groupValue: mode,
                  onChanged: (value) {
                    if (value != null) settings.setTheme(value);
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
