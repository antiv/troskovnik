import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/db/providers.dart';
import '../../../core/domain/currency.dart';
import '../../../core/providers/last_currency_controller.dart';
import '../domain/analytics_models.dart';
import 'analytics_repository.dart';

/// Izabrana valuta za prikaz analitike. Pamti eksplicitan izbor korisnika
/// (flutter_secure_storage — isti pristup kao [LastCurrencyController]).
/// Dok korisnik ne promeni filter na ovom ekranu, koristi se poslednja
/// valuta izabrana pri ručnom unosu; `null` = nema ni jedno ni drugo,
/// prikazuje se prva dostupna valuta.
class AnalyticsCurrencyNotifier extends AsyncNotifier<Currency?> {
  static const _key = 'analytics_currency_v1';
  final _storage = const FlutterSecureStorage();

  @override
  Future<Currency?> build() async {
    final stored = await _storage.read(key: _key);
    if (stored != null) {
      final explicit =
          Currency.values.firstWhereOrNull((c) => c.name == stored);
      if (explicit != null) return explicit;
    }
    return ref.watch(lastCurrencyControllerProvider.future);
  }

  Future<void> set(Currency? c) async {
    state = AsyncData(c);
    if (c == null) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: c.name);
    }
  }
}

final analyticsCurrencyProvider =
    AsyncNotifierProvider<AnalyticsCurrencyNotifier, Currency?>(
        AnalyticsCurrencyNotifier.new);

/// Izabrani period analitike.
class AnalyticsRangeNotifier extends Notifier<AnalyticsRange> {
  @override
  AnalyticsRange build() => AnalyticsRange.last12Months;

  void set(AnalyticsRange range) => state = range;
}

final analyticsRangeProvider =
    NotifierProvider<AnalyticsRangeNotifier, AnalyticsRange>(
        AnalyticsRangeNotifier.new);

final analyticsRepositoryProvider =
    FutureProvider<AnalyticsRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return AnalyticsRepository(db);
});

/// Reaktivni sažetak analitike za izabrani period i valutu.
final analyticsSummaryProvider =
    StreamProvider<AnalyticsSummary>((ref) async* {
  final repo = await ref.watch(analyticsRepositoryProvider.future);
  final range = ref.watch(analyticsRangeProvider);
  final currency = await ref.watch(analyticsCurrencyProvider.future);
  yield* repo.watchSummary(range, currency: currency);
});

/// Detalji za jednog prodavca (drill-down), za trenutno izabrani period.
final merchantDetailProvider =
    FutureProvider.family<MerchantDetail, int>((ref, merchantId) async {
  final repo = await ref.watch(analyticsRepositoryProvider.future);
  final range = ref.watch(analyticsRangeProvider);
  return repo.merchantDetail(merchantId, range);
});

/// Detalji za jedan artikal (po nazivu) (drill-down), za izabrani period.
final itemDetailProvider =
    FutureProvider.family<ItemDetail, String>((ref, name) async {
  final repo = await ref.watch(analyticsRepositoryProvider.future);
  final range = ref.watch(analyticsRangeProvider);
  return repo.itemDetail(name, range);
});

/// Artikli jedne kategorije (drill-down; 0 = bez kategorije), za izabrani
/// period i valutu.
final categoryItemsProvider =
    FutureProvider.family<List<TopItem>, int>((ref, categoryId) async {
  final repo = await ref.watch(analyticsRepositoryProvider.future);
  final range = ref.watch(analyticsRangeProvider);
  final currency = await ref.watch(analyticsCurrencyProvider.future);
  return repo.categoryItems(categoryId, range, currency: currency);
});
