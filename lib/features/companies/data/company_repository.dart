import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/country.dart';

/// Firme kupca (PIB/JIB/TIN) — korisnički naziv za analitiku po firmama.
/// Zapise kreira `ReceiptRepository` pri upisu računa sa PIB-om kupca.
class CompanyRepository {
  CompanyRepository(this._db);

  final AppDatabase _db;

  Stream<CompanyRow?> watch(Country country, String taxId) =>
      (_db.select(_db.companies)
            ..where((c) => c.country.equalsValue(country) & c.taxId.equals(taxId)))
          .watchSingleOrNull();

  /// Postavi naziv firme; prazan naziv briše naziv (prikazuje se PIB).
  Future<void> setName(Country country, String taxId, String? name) async {
    final trimmed = name?.trim();
    await _db.into(_db.companies).insert(
          CompaniesCompanion.insert(
            country: Value(country),
            taxId: taxId,
            name: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
          ),
          onConflict: DoUpdate(
            (_) => CompaniesCompanion(
              name: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
            ),
            target: [_db.companies.country, _db.companies.taxId],
          ),
        );
  }
}
