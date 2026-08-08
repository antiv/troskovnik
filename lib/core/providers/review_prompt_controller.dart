import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_review/in_app_review.dart';

import '../domain/review_prompter.dart';

/// Implementacija preko `in_app_review` paketa.
class InAppReviewPrompter implements ReviewPrompter {
  InAppReviewPrompter({InAppReview? review})
      : _review = review ?? InAppReview.instance;

  final InAppReview _review;

  @override
  Future<bool> isAvailable() => _review.isAvailable();

  @override
  Future<void> requestReview() => _review.requestReview();
}

/// Prompter — override-uje se u testovima fake-om.
final reviewPrompterProvider =
    Provider<ReviewPrompter>((ref) => InAppReviewPrompter());

/// Skladište brojača — izdvojeno u provider da testovi ne diraju platform kanal.
final reviewPromptStorageProvider =
    Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

/// Broji uspešna skeniranja i traži ocenu kad se dostigne prag.
///
/// Zašto: aplikacija nema nijednu ocenu na App Store-u, a ocene utiču i na
/// rangiranje u pretrazi i na to da li posetilac listinga instalira. Retencija
/// je visoka (~72% instalacija ostane aktivno), pa bazen zadovoljnih korisnika
/// postoji — samo ih do sada niko nije pitao.
///
/// Perzistencija ide preko `flutter_secure_storage`, isti pristup kao
/// `LocaleController` i `LastCurrencyController` — bez nove zavisnosti.
class ReviewPromptController extends AsyncNotifier<int> {
  static const _countKey = 'successful_scans_v1';
  static const _askedKey = 'review_asked_v1';

  /// Prag namerno nije 1: ocena se traži tek kad je vrednost dokazana.
  static const threshold = 5;

  FlutterSecureStorage get _storage => ref.read(reviewPromptStorageProvider);

  @override
  Future<int> build() async {
    final stored = await _storage.read(key: _countKey);
    return int.tryParse(stored ?? '') ?? 0;
  }

  /// Zabeleži jedno uspešno skeniranje i, ako je prag dostignut, zatraži ocenu.
  ///
  /// Poziva se SAMO za stvarno uspešna skeniranja — ne za duplikate i ne za
  /// račune sačuvane bez mreže. Traženje ocene posle neuspeha je najbrži način
  /// da se dobije jedna zvezdica.
  Future<void> recordSuccessfulScan() async {
    // Ako se brojač još učitava, preskačemo — jedno neizbrojano skeniranje je
    // bezazleno, a čekanje na `future` ovde nije vredno komplikacije.
    final current = state.value;
    if (current == null) return;
    final next = current + 1;
    state = AsyncData(next);
    await _storage.write(key: _countKey, value: '$next');

    if (next < threshold) return;
    // Pitamo najviše jednom u životu aplikacije.
    final asked = await _storage.read(key: _askedKey);
    if (asked != null) return;

    final prompter = ref.read(reviewPrompterProvider);
    if (!await prompter.isAvailable()) return;

    // Upisujemo PRE poziva: ako poziv pukne ili je sistemska kvota potrošena,
    // korisnika svejedno ne maltretiramo ponovo.
    await _storage.write(
      key: _askedKey,
      value: DateTime.now().toIso8601String(),
    );
    await prompter.requestReview();
  }
}

final reviewPromptControllerProvider =
    AsyncNotifierProvider<ReviewPromptController, int>(
        ReviewPromptController.new);
