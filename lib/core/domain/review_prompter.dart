/// Apstrakcija nad traženjem ocene u prodavnici.
///
/// Konkretna implementacija (`InAppReviewPrompter`) zove sistemski dijalog —
/// Play In-App Review API na Androidu, `SKStoreReviewController` na iOS-u.
/// Izdvojeno iza interfejsa iz istog razloga kao `WarrantyNotifier`: da se
/// logika praga može testirati bez platform kanala.
abstract class ReviewPrompter {
  /// Da li je sistemski dijalog uopšte dostupan na ovom uređaju.
  Future<bool> isAvailable();

  /// Zatraži prikaz dijaloga.
  ///
  /// Namerno ne vraća ništa: ni Apple ni Google ne kažu da li je dijalog
  /// zaista prikazan. Apple dozvoljava najviše 3 prikaza godišnje po
  /// korisniku, Google ima svoje kvote, i u oba slučaja poziv tiho ne uradi
  /// ništa kad je kvota potrošena. Zato nijedan deo UI-ja ne sme da zavisi
  /// od ishoda ovog poziva.
  Future<void> requestReview();
}
