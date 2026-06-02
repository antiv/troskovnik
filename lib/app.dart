import 'package:flutter/material.dart';

import 'core/l10n/gen/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_shell.dart';

/// Root widget: wires up theme and SR/EN localization (SR default).
class TroskovnikApp extends StatelessWidget {
  const TroskovnikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeShell(),
    );
  }
}
