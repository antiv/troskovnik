import '../domain/warranty_status.dart';

/// Apstrakcija nad zakazivanjem podsetnika za isteke garancija.
///
/// Iza interfejsa stoji flutter_local_notifications (vidi
/// [LocalWarrantyNotifier]); ovako je raspored logike testabilan bez plugina.
abstract interface class WarrantyNotifier {
  /// Zakaži podsetnike (30d i 7d pre isteka) za garanciju [warrantyId].
  /// Implementacija preskače termine koji su u prošlosti.
  Future<void> scheduleReminders({
    required int warrantyId,
    required String title,
    required DateTime expiryDate,
    DateTime? now,
  });

  /// Otkaži sve podsetnike vezane za garanciju (npr. pri brisanju/izmeni).
  Future<void> cancelReminders(int warrantyId);
}

/// Računa konkretne termine podsetnika (čista funkcija, testirana zasebno).
class ReminderSchedule {
  const ReminderSchedule({required this.fireAt, required this.daysBefore});
  final DateTime fireAt;
  final int daysBefore;

  /// Termini = expiry - offset, samo oni u budućnosti u odnosu na [now].
  static List<ReminderSchedule> compute(DateTime expiryDate,
      {DateTime? now}) {
    final ts = now ?? DateTime.now();
    final out = <ReminderSchedule>[];
    for (final offset in WarrantyTiming.reminderOffsets) {
      final fireAt = expiryDate.subtract(offset);
      if (fireAt.isAfter(ts)) {
        out.add(ReminderSchedule(fireAt: fireAt, daysBefore: offset.inDays));
      }
    }
    return out;
  }
}

/// Determinističko mapiranje (warrantyId, daysBefore) → jedinstven notif id.
/// Dozvoljava precizno otkazivanje. Drži se u 32-bit opsegu (Android zahtev).
int warrantyNotificationId(int warrantyId, int daysBefore) =>
    ((warrantyId & 0xFFFFFF) << 6) | (daysBefore & 0x3F);
