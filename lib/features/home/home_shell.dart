import 'package:flutter/material.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../receipts/presentation/receipt_list_screen.dart';
import '../scan/presentation/scanner_screen.dart';
import '../warranties/presentation/warranty_list_screen.dart';

/// Glavni shell sa donjom navigacijom: Skener / Računi.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titles = [l10n.scanTitle, l10n.receiptsTitle, l10n.warrantiesTitle];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_index])),
      body: IndexedStack(
        index: _index,
        children: const [
          ScannerScreen(),
          ReceiptListScreen(),
          WarrantyListScreen(),
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
        ],
      ),
    );
  }
}
