import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../source/data/taxcore_client.dart';
import '../../source/domain/receipt_source.dart';
import 'receipt_repository.dart';
import 'refetch_service.dart';

/// Izvor podataka računa (TaxCore portal preko dio).
final receiptSourceProvider =
    Provider<ReceiptSource>((ref) => TaxCoreClient());

/// Repository — dostupan tek kad se baza otvori.
final receiptRepositoryProvider = FutureProvider<ReceiptRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return ReceiptRepository(db);
});

/// Servis za re-fetch (ručno „Osveži" i background).
final refetchServiceProvider = FutureProvider<RefetchService>((ref) async {
  final repo = await ref.watch(receiptRepositoryProvider.future);
  final source = ref.watch(receiptSourceProvider);
  return RefetchService(source, repo);
});
