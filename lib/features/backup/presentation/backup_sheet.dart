import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../warranties/data/warranty_providers.dart';
import '../data/backup_providers.dart';
import '../data/backup_service.dart';

class BackupSheet extends ConsumerStatefulWidget {
  const BackupSheet({super.key});

  @override
  ConsumerState<BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends ConsumerState<BackupSheet> {
  bool _loading = false;
  bool _picking = false; // guard against concurrent pickFiles calls

  Future<void> _export() async {
    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = await ref.read(backupServiceProvider.future);
      final path = await service.exportToZip();
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } on BackupException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'corrupt'
          ? l10n.backupErrorCorrupt
          : l10n.backupError;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupError)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    if (_loading || _picking) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _picking = true);
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
    } catch (_) {
      if (mounted) setState(() => _picking = false);
      return;
    }
    if (mounted) setState(() => _picking = false);

    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupImportConfirmTitle),
        content: Text(l10n.backupImportConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.backupImport),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final service = await ref.read(backupServiceProvider.future);
      await service.importFromZip(path);
      if (!mounted) return;
      // Invalidate warranty list so existsSync() re-evaluates after images land.
      ref.invalidate(warrantyListProvider);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupSuccess)));
    } on BackupException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'corrupt'
          ? l10n.backupErrorCorrupt
          : l10n.backupError;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupError)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.backupTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.backupExplain,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _export,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.backup_outlined),
              label: Text(l10n.backupCreate),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: (_loading || _picking) ? null : _import,
              icon: const Icon(Icons.upload_outlined),
              label: Text(l10n.backupImport),
            ),
          ],
        ),
      ),
    );
  }
}
