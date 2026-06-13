import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import 'local_warranty_notifier.dart';
import 'warranty_notifier.dart';
import 'warranty_repository.dart';

/// Notifier za podsetnike garancija. Override-ovan u testovima fake-om.
final warrantyNotifierProvider = FutureProvider<WarrantyNotifier>((ref) async {
  return LocalWarrantyNotifier.create();
});

/// Repository garancija — dostupan kad se baza i notifier otvore.
final warrantyRepositoryProvider =
    FutureProvider<WarrantyRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final notifier = await ref.watch(warrantyNotifierProvider.future);
  return WarrantyRepository(db, notifier);
});

/// Reaktivna lista svih garancija (sortirana po roku isteka).
final warrantyListProvider =
    StreamProvider<List<WarrantyView>>((ref) async* {
  final repo = await ref.watch(warrantyRepositoryProvider.future);
  yield* repo.watchAll();
});

/// Pojam pretrage garancija (po nazivu, prodavcu ili artiklu).
class WarrantySearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String search) => state = search;
}

final warrantySearchProvider =
    NotifierProvider<WarrantySearchNotifier, String>(WarrantySearchNotifier.new);

/// Lista garancija filtrirana po [warrantySearchProvider]. Filtrira se u Dart-u
/// nad već učitanom listom (mali broj garancija po korisniku).
final filteredWarrantyListProvider =
    Provider<AsyncValue<List<WarrantyView>>>((ref) {
  final listAsync = ref.watch(warrantyListProvider);
  final term = ref.watch(warrantySearchProvider).trim().toLowerCase();
  return listAsync.whenData((items) {
    if (term.isEmpty) return items;
    return items
        .where((v) =>
            v.warranty.title.toLowerCase().contains(term) ||
            v.merchantName.toLowerCase().contains(term) ||
            (v.lineItemName?.toLowerCase().contains(term) ?? false))
        .toList();
  });
});
