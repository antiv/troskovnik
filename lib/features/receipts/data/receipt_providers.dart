import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../source/data/taxcore_client.dart';
import '../../source/domain/receipt_source.dart';
import '../../warranties/data/warranty_providers.dart';
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

/// Obriši račun i otkaži notifikacije za sve njegove (kaskadno obrisane)
/// garancije (#7). Prima WidgetRef (poziva se iz UI-ja).
Future<void> deleteReceipt(WidgetRef ref, int receiptId) async {
  final repo = await ref.read(receiptRepositoryProvider.future);
  final notifier = await ref.read(warrantyNotifierProvider.future);
  final warrantyIds = await repo.delete(receiptId);
  for (final id in warrantyIds) {
    await notifier.cancelReminders(id);
  }
}
