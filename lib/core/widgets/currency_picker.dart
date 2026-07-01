import 'package:flutter/material.dart';

import '../domain/currency.dart';

/// Kružno dugme za izbor valute sa bedžom koji prikazuje trenutno izabrani
/// kod/simbol u uglu. Otvara padajući meni sa dostupnim valutama.
///
/// Kad je [allLabel] zadat, meni dobija dodatnu stavku za sve valute
/// ([selected] == null bira tu stavku); u suprotnom se bira isključivo
/// konkretna valuta.
class CurrencyPicker extends StatelessWidget {
  const CurrencyPicker({
    super.key,
    required this.currencies,
    required this.selected,
    required this.onSelected,
    this.allLabel,
    this.labelBuilder,
  });

  final List<Currency> currencies;
  final Currency? selected;
  final ValueChanged<Currency?> onSelected;

  /// Kad je zadat, meni dobija opciju za sve valute (vrednost `null`).
  final String? allLabel;

  /// Tekst za pojedinačnu valutu; podrazumevano ISO kod (npr. "RSD").
  final String Function(Currency)? labelBuilder;

  String _labelFor(Currency? c) =>
      c == null ? allLabel! : (labelBuilder?.call(c) ?? c.isoCode);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badgeLabel = _labelFor(selected);

    return PopupMenuButton<Currency?>(
      tooltip: badgeLabel,
      onSelected: onSelected,
      itemBuilder: (_) => [
        if (allLabel != null)
          PopupMenuItem<Currency?>(
            value: null,
            child: Row(
              children: [
                if (selected == null)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(allLabel!),
              ],
            ),
          ),
        for (final c in currencies)
          PopupMenuItem<Currency?>(
            value: c,
            child: Row(
              children: [
                if (c == selected)
                  const Icon(Icons.check, size: 16)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(_labelFor(c)),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6, right: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.monetization_on_outlined,
                size: 20,
                color: scheme.onSurface,
              ),
            ),
            Positioned(
              bottom: -6,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
