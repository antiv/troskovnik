import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';

/// Podešavanja: izbor jezika (srpski ćirilica/latinica, engleski, sistemski).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current =
        ref.watch(localeControllerProvider).value ?? AppLanguage.system;

    String label(AppLanguage lang) => switch (lang) {
          AppLanguage.system => l10n.languageSystem,
          AppLanguage.serbianCyrillic => l10n.languageSerbianCyrillic,
          AppLanguage.serbianLatin => l10n.languageSerbianLatin,
          AppLanguage.english => l10n.languageEnglish,
        };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: RadioGroup<AppLanguage>(
        groupValue: current,
        onChanged: (v) {
          if (v != null) {
            ref.read(localeControllerProvider.notifier).setLanguage(v);
          }
        },
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(l10n.settingsLanguage,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final lang in AppLanguage.values)
              RadioListTile<AppLanguage>(
                value: lang,
                title: Text(label(lang)),
              ),
          ],
        ),
      ),
    );
  }
}
