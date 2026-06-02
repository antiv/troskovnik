import 'package:flutter/material.dart';

import '../../../../core/l10n/gen/app_localizations.dart';
import '../../domain/warranty_status.dart';

/// Bedž statusa garancije (Važi / Ističe uskoro / Isteklo).
class WarrantyStatusBadge extends StatelessWidget {
  const WarrantyStatusBadge({super.key, required this.status});

  final WarrantyStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final (String label, Color bg, Color fg, IconData icon) = switch (status) {
      WarrantyStatus.active => (
          l10n.warrantyStatusActive,
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Icons.verified_user,
        ),
      WarrantyStatus.expiringSoon => (
          l10n.warrantyStatusExpiringSoon,
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.warning_amber,
        ),
      WarrantyStatus.expired => (
          l10n.warrantyStatusExpired,
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.event_busy,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
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
}
