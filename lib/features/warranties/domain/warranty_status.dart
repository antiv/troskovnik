/// Status garancije i računanje roka isteka (killer feature).
library;

enum WarrantyStatus {
  /// Garancija važi, ostalo je više od praga „uskoro".
  active,

  /// Ističe uskoro (unutar [WarrantyTiming.soonThreshold]).
  expiringSoon,

  /// Rok je istekao.
  expired,
}

class WarrantyTiming {
  WarrantyTiming._();

  /// Podrazumevano trajanje (zakonska saobraznost u Srbiji).
  static const defaultDurationMonths = 24;

  /// Prag „ističe uskoro".
  static const soonThreshold = Duration(days: 30);

  /// Pomeraji za podsetnike pre isteka (sekcija notifikacija).
  static const reminderOffsets = [Duration(days: 30), Duration(days: 7)];

  /// Datum isteka = datum kupovine + trajanje u mesecima (kalendarski).
  static DateTime expiryFrom(DateTime purchaseDate, int durationMonths) {
    final y = purchaseDate.year + (purchaseDate.month - 1 + durationMonths) ~/ 12;
    final m = (purchaseDate.month - 1 + durationMonths) % 12 + 1;
    // Rukuj prelivanjem dana (npr. 31. + mesec bez 31 dana).
    final lastDay = DateTime(y, m + 1, 0).day;
    final d = purchaseDate.day <= lastDay ? purchaseDate.day : lastDay;
    return DateTime(y, m, d, purchaseDate.hour, purchaseDate.minute,
        purchaseDate.second);
  }

  /// Status na osnovu datuma isteka i trenutnog vremena.
  static WarrantyStatus statusOf(DateTime expiry, {DateTime? now}) {
    final ts = now ?? DateTime.now();
    if (!expiry.isAfter(ts)) return WarrantyStatus.expired;
    if (expiry.difference(ts) <= soonThreshold) {
      return WarrantyStatus.expiringSoon;
    }
    return WarrantyStatus.active;
  }

  /// Preostali broj dana do isteka (može biti negativan ako je isteklo).
  static int daysLeft(DateTime expiry, {DateTime? now}) {
    final ts = now ?? DateTime.now();
    return expiry.difference(ts).inDays;
  }
}
