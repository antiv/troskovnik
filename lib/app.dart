import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/gen/app_localizations.dart';
import 'core/l10n/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_shell.dart';

/// Root widget: wires up theme and SR (latinica/ćirilica) / EN localization.
class TroskovnikApp extends ConsumerWidget {
  const TroskovnikApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Izabrani jezik (null/system = prati uređaj). Dok se učitava, system.
    final language =
        ref.watch(localeControllerProvider).value ?? AppLanguage.system;

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: language.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Kad je uređaj na srpskom bez skripta, podrazumevaj ćirilicu (tržište).
      localeResolutionCallback: _resolveLocale,
      home: const HomeShell(),
    );
  }

  /// Razrešavanje lokala: ako je traženi jezik srpski bez eksplicitnog pisma,
  /// biramo ćirilicu kao podrazumevanu za srpsko tržište.
  static Locale? _resolveLocale(Locale? device, Iterable<Locale> supported) {
    if (device == null) return null;
    if (device.languageCode == 'sr' && device.scriptCode == null) {
      return const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Cyrl');
    }
    // Podrazumevano ponašanje: tačno poklapanje pa fallback na prvi.
    for (final s in supported) {
      if (s.languageCode == device.languageCode &&
          s.scriptCode == device.scriptCode) {
        return s;
      }
    }
    for (final s in supported) {
      if (s.languageCode == device.languageCode) return s;
    }
    return null;
  }
}
