import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/currency.dart';

/// Pamti poslednju izabranu valutu kod ručnog unosa troška, kao default
/// za sledeći unos (flutter_secure_storage — isti pristup kao [LocaleController]).
class LastCurrencyController extends AsyncNotifier<Currency> {
  static const _key = 'last_manual_currency_v1';
  final _storage = const FlutterSecureStorage();

  @override
  Future<Currency> build() async {
    final stored = await _storage.read(key: _key);
    return Currency.values.firstWhere(
      (c) => c.name == stored,
      orElse: () => Currency.rsd,
    );
  }

  Future<void> setCurrency(Currency currency) async {
    state = AsyncData(currency);
    await _storage.write(key: _key, value: currency.name);
  }
}

final lastCurrencyControllerProvider =
    AsyncNotifierProvider<LastCurrencyController, Currency>(
        LastCurrencyController.new);
