import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/db_recovery.dart';
import '../../core/db/providers.dart';
import '../../core/l10n/gen/app_localizations.dart';

/// Presretač ispred glavnog shell-a: ako se baza ne može dešifrovati, umesto
/// mrtve aplikacije (svaki tab bi prikazao „Došlo je do greške" + tekst
/// SqliteException-a) prikaže ekran sa jedinim mogućim izlazom — brisanjem.
///
/// Sve ostale greške propuštamo dalje: ekrani ih prikazuju sami, a destruktivnu
/// akciju nudimo samo kad je baza stvarno nečitljiva.
class DatabaseGate extends ConsumerWidget {
  const DatabaseGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(appDatabaseProvider).error;
    if (error != null && isUnreadableDatabase(error)) {
      return const DatabaseRecoveryScreen();
    }
    return child;
  }
}

/// Ekran oporavka: objasni šta se desilo i ponudi brisanje podataka.
class DatabaseRecoveryScreen extends ConsumerStatefulWidget {
  const DatabaseRecoveryScreen({super.key});

  @override
  ConsumerState<DatabaseRecoveryScreen> createState() =>
      _DatabaseRecoveryScreenState();
}

class _DatabaseRecoveryScreenState
    extends ConsumerState<DatabaseRecoveryScreen> {
  bool _busy = false;

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.dbRecoveryConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.dbRecoveryReset),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await resetEncryptedDatabase(ref.read(dbKeyManagerProvider));
      // Novo otvaranje napravi ključ i praznu bazu (fajla više nema).
      ref.invalidate(appDatabaseProvider);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.dbRecoveryError)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 56, color: scheme.error),
                const SizedBox(height: 20),
                Text(
                  l10n.dbRecoveryTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.dbRecoveryBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _busy ? null : _reset,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_outlined),
                  label: Text(l10n.dbRecoveryReset),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
