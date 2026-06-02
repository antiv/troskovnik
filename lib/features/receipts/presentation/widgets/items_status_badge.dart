import 'package:flutter/material.dart';

import '../../../../core/db/enums.dart';
import '../../../../core/l10n/gen/app_localizations.dart';

/// Bedž stanja stavki/računa za listu i detalj (sekcija 5 UI tretman).
class ItemsStatusBadge extends StatelessWidget {
  const ItemsStatusBadge({
    super.key,
    required this.fetchStatus,
    required this.itemsStatus,
  });

  final FetchStatus fetchStatus;
  final ItemsStatus itemsStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (fetchStatus == FetchStatus.invalid) {
      return _chip(l10n.badgeInvalid, scheme.errorContainer,
          scheme.onErrorContainer, Icons.error_outline);
    }
    switch (itemsStatus) {
      case ItemsStatus.pendingServer:
        return _chip(l10n.badgeItemsPending, scheme.tertiaryContainer,
            scheme.onTertiaryContainer, Icons.hourglass_top);
      case ItemsStatus.fromJournal:
        return _chip(l10n.badgeFromJournal, scheme.secondaryContainer,
            scheme.onSecondaryContainer, Icons.notes);
      case ItemsStatus.none:
      case ItemsStatus.fromSpecifications:
        return const SizedBox.shrink();
    }
  }

  Widget _chip(String label, Color bg, Color fg, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: fg, fontSize: 12)),
          ],
        ),
      );
}
