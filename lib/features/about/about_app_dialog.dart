import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/gen/app_localizations.dart';

/// "O aplikaciji" popup: ikonica, naziv, verzija i "powered by" Ant BioCode
/// logo koji vodi na antonijevic.rs.
class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({super.key});

  static const _siteUrl = 'https://antonijevic.rs';

  /// Otvori About popup (obrazac kao [CategoryPickerSheet.show]).
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const AboutAppDialog(),
    );
  }

  Future<void> _openSite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final uri = Uri.parse(_siteUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w600,
    );

    return Dialog(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ikonica aplikacije (izvor je velik ~1516px → cacheWidth).
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/icon/appstore.png',
                  width: 76,
                  height: 76,
                  cacheWidth: 152,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.appTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Red verzije.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.aboutVersionLabel, style: labelStyle),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    final text = info == null
                        ? ''
                        : '${info.version}+${info.buildNumber}';
                    return Text(
                      text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    );
                  },
                ),
              ],
            ),
            Divider(height: 32, color: scheme.outlineVariant),
            // "powered by" red sa klikabilnim logom (Flexible → bez overflow-a).
            Row(
              children: [
                Text(l10n.aboutPoweredBy, style: labelStyle),
                const SizedBox(width: 12),
                Flexible(
                  child: InkWell(
                    onTap: () => _openSite(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Image.asset(
                          'assets/icon/ant-biocode.png',
                          height: 22,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.aboutClose),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
