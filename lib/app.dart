import 'package:flutter/material.dart';

import 'core/l10n/gen/app_localizations.dart';
import 'core/theme/app_theme.dart';

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
      home: const _HomeShell(),
    );
  }
}

/// Temporary shell so the app compiles and runs during FAZA 0.
/// Real screens (scanner, receipts list) replace this in the screens phase.
class _HomeShell extends StatelessWidget {
  const _HomeShell();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(child: Text(l10n.scanHint)),
    );
  }
}
