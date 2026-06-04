import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../analytics/presentation/analytics_screen.dart';
import '../receipts/presentation/receipt_list_screen.dart';
import '../scan/presentation/scanner_screen.dart';
import '../settings/settings_screen.dart';
import '../warranties/presentation/warranty_list_screen.dart';

/// Glavni shell sa donjom navigacijom: Skener / Računi / Garancije / Analitika.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language =
        ref.watch(localeControllerProvider).value ?? AppLanguage.system;
    final titles = [
      l10n.scanTitle,
      l10n.receiptsTitle,
      l10n.warrantiesTitle,
      l10n.analyticsTitle,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          // Indikator jezika (zastavica + skraćenica) → otvara podešavanja (#6).
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen()),
              ),
              child: Text('${language.flag} ${language.shortCode}',
                  style: const TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          ScannerScreen(),
          ReceiptListScreen(),
          WarrantyListScreen(),
          AnalyticsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.qr_code_scanner), label: l10n.navScan),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long), label: l10n.navReceipts),
          NavigationDestination(
              icon: const Icon(Icons.shield_outlined),
              label: l10n.navWarranties),
          NavigationDestination(
              icon: const Icon(Icons.bar_chart), label: l10n.navAnalytics),
        ],
      ),
    );
  }
}
