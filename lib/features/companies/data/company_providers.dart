import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../../../core/domain/country.dart';
import 'company_repository.dart';

final companyRepositoryProvider =
    FutureProvider<CompanyRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return CompanyRepository(db);
});

/// Firma kupca po (zemlja, PIB) — za prikaz naziva na detalju računa.
final companyProvider =
    StreamProvider.family<CompanyRow?, (Country, String)>((ref, key) async* {
  final repo = await ref.watch(companyRepositoryProvider.future);
  yield* repo.watch(key.$1, key.$2);
});
