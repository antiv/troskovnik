import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../about/about_app_dialog.dart';
import '../backup/presentation/backup_sheet.dart';
import '../analytics/presentation/analytics_screen.dart';
import '../receipts/presentation/receipt_list_screen.dart';
import '../scan/presentation/manual_expense_screen.dart';
import '../scan/presentation/scanner_screen.dart';
import '../warranties/presentation/warranty_list_screen.dart';

/// Glavni shell sa donjom navigacijom: Skener / Računi / Garancije / Analitika.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  // Promocija druge aplikacije istog autora — link na prodavnicu za tekuću
  // platformu.
  static const _invoice2IpsPlay =
      'https://play.google.com/store/apps/details?id=rs.antonijevic.invoice2ips';
  static const _invoice2IpsAppStore = 'https://apps.apple.com/app/id6783432330';

  Future<void> _openMoreApps(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final uri =
        Uri.parse(Platform.isIOS ? _invoice2IpsAppStore : _invoice2IpsPlay);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    }
  }

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

    String label(AppLanguage lang) => switch (lang) {
          AppLanguage.system => l10n.languageSystem,
          AppLanguage.serbianCyrillic => l10n.languageSerbianCyrillic,
          AppLanguage.serbianLatin => l10n.languageSerbianLatin,
          AppLanguage.english => l10n.languageEnglish,
        };

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          // Izbor jezika (zastavica + skraćenica) → dropdown sa svim jezicima.
          PopupMenuButton<AppLanguage>(
            tooltip: l10n.languageSystem,
            onSelected: (v) =>
                ref.read(localeControllerProvider.notifier).setLanguage(v),
            itemBuilder: (context) => [
              for (final lang in AppLanguage.values)
                PopupMenuItem<AppLanguage>(
                  value: lang,
                  child: Row(
                    children: [
                      Text(lang.flag),
                      const SizedBox(width: 12),
                      Expanded(child: Text(label(lang))),
                      if (lang == language)
                        const Icon(Icons.check, size: 18),
                    ],
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text('${language.flag} ${language.shortCode}',
                    style: const TextStyle(fontSize: 14)),
              ),
            ),
          ),
          // Overflow meni: Backup + O aplikaciji + Još aplikacija.
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem<void>(
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => const BackupSheet(),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.backup_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(l10n.backupMenuLabel),
                  ],
                ),
              ),
              PopupMenuItem<void>(
                onTap: () => AboutAppDialog.show(context),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 12),
                    Text(l10n.aboutTitle),
                  ],
                ),
              ),
              PopupMenuItem<void>(
                onTap: () => _openMoreApps(context),
                child: Row(
                  children: [
                    const Icon(Icons.apps_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(l10n.moreAppsLabel),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          ScannerScreen(isActive: _index == 0),
          const ReceiptListScreen(),
          const WarrantyListScreen(),
          const AnalyticsScreen(),
        ],
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton(
              tooltip: l10n.scanAddExpense,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const ManualExpenseScreen()),
              ),
              child: const Icon(Icons.add),
            )
          : null,
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
