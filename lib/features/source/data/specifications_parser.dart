import 'dart:convert';

import '../../../core/db/enums.dart';
import '../domain/receipt_source.dart';

/// Parsira izdvojene stavke iz `/specifications` JSON odgovora.
///
/// Oblik potvrđen iz invoice-verify.js (ItemSpecification):
/// {success: bool, items: [{name, quantity, unitPrice, total, label,
///  labelRate, taxBaseAmount, vatAmount, gtin}]}.
/// Iznosi u JSON-u su decimalni (RSD); konvertuju se u para.
class SpecificationsParser {
  const SpecificationsParser();

  /// Vraća stavke ili null ako telo nedostaje / nije uspešno / nema stavki.
  List<ParsedLineItem>? tryParse(String? body) {
    if (body == null || body.trim().isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    if (decoded['success'] != true) return null;
    final items = decoded['items'];
    if (items is! List || items.isEmpty) return null;

    final result = <ParsedLineItem>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final name = (raw['name'] ?? '').toString();
      result.add(ParsedLineItem(
        name: name,
        quantity: _toDouble(raw['quantity']) ?? 1.0,
        unitPrice: _toMinor(raw['unitPrice']),
        total: _toMinor(raw['total']),
        taxLabel: raw['label']?.toString(),
        taxRate: _toDouble(raw['labelRate']),
        source: ItemsSource.specifications,
      ));
    }
    return result.isEmpty ? null : result;
  }

  static double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }

  static int _toMinor(Object? v) {
    final d = _toDouble(v);
    return d == null ? 0 : (d * 100).round();
  }
}
