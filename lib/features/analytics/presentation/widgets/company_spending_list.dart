import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/country.dart';
import '../../../../core/domain/currency.dart';
import '../../../../core/l10n/gen/app_localizations.dart';
import '../../../../core/utils/money_format.dart';
import '../../../companies/data/company_providers.dart';
import '../../domain/analytics_models.dart';

/// Poslovna potrošnja po firmi kupca (PIB/JIB). Klik na firmu otvara unos
/// naziva; red bez PIB-a (ručno označeni poslovni) nije interaktivan.
class CompanySpendingList extends ConsumerWidget {
  const CompanySpendingList({
    super.key,
    required this.items,
    required this.currency,
  });

  final List<CompanySpending> items;
  final Currency currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final maxV = items.isEmpty
        ? 1
        : items.map((c) => c.totalMinor).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final c in items)
          InkWell(
            onTap: c.taxId == null ? null : () => _editName(context, ref, c),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.taxId == null
                              ? l10n.analyticsCompanyNoTaxId
                              : (c.name ?? '${_taxIdLabel(c.country)} ${c.taxId}'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (c.taxId != null)
                        Icon(Icons.edit_outlined,
                            size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(MoneyFormat.fromMinor(c.totalMinor, currency),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (c.taxId != null && c.name != null)
                        '${_taxIdLabel(c.country)} ${c.taxId}',
                      l10n.analyticsReceiptCount(c.receiptCount),
                      if (c.vatMinor != 0)
                        l10n.analyticsCompanyVat(
                            MoneyFormat.fromMinor(c.vatMinor, currency)),
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxV <= 0
                          ? 0
                          : (c.totalMinor / maxV).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _taxIdLabel(Country country) =>
      country == Country.republikaSrpska ? 'JIB' : 'PIB';

  Future<void> _editName(
      BuildContext context, WidgetRef ref, CompanySpending c) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CompanyNameDialog(
        taxIdText: '${_taxIdLabel(c.country)} ${c.taxId}',
        name: c.name ?? '',
      ),
    );
    if (name == null) return;
    final repo = await ref.read(companyRepositoryProvider.future);
    await repo.setName(c.country, c.taxId!, name);
  }
}

class _CompanyNameDialog extends StatefulWidget {
  const _CompanyNameDialog({required this.taxIdText, required this.name});
  final String taxIdText;
  final String name;

  @override
  State<_CompanyNameDialog> createState() => _CompanyNameDialogState();
}

class _CompanyNameDialogState extends State<_CompanyNameDialog> {
  late final _ctrl = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.companyNameTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.taxIdText),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.companyNameHint),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
