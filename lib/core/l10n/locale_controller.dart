import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Izbor jezika u aplikaciji. `null` (system) znači da se prati lokal uređaja.
///
/// Za srpsko tržište podržavamo ćirilicu i latinicu odvojeno, plus engleski.
enum AppLanguage {
  system,
  serbianCyrillic,
  serbianLatin,
  english;

  /// Lokal koji se prosleđuje MaterialApp-u (null = prati uређaj).
  Locale? get locale => switch (this) {
        AppLanguage.system => null,
        AppLanguage.serbianCyrillic =>
          const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Cyrl'),
        AppLanguage.serbianLatin => const Locale('sr'),
        AppLanguage.english => const Locale('en'),
      };

  /// Stabilan ključ za čuvanje.
  String get storageKey => name;

  static AppLanguage fromStorage(String? value) {
    return AppLanguage.values.firstWhere(
      (l) => l.name == value,
      orElse: () => AppLanguage.system,
    );
  }
}

/// Drži i perzistira izabrani jezik (flutter_secure_storage — bez nove zavisnosti).
class LocaleController extends AsyncNotifier<AppLanguage> {
  static const _key = 'app_language_v1';
  final _storage = const FlutterSecureStorage();

  @override
  Future<AppLanguage> build() async {
    final stored = await _storage.read(key: _key);
    return AppLanguage.fromStorage(stored);
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = AsyncData(language);
    await _storage.write(key: _key, value: language.storageKey);
  }
}

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, AppLanguage>(LocaleController.new);
