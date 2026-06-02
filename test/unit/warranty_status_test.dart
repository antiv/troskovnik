import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/features/warranties/domain/warranty_status.dart';

void main() {
  group('WarrantyTiming.expiryFrom', () {
    test('adds whole months (default 24)', () {
      final exp = WarrantyTiming.expiryFrom(DateTime(2026, 6, 2), 24);
      expect(exp, DateTime(2028, 6, 2));
    });

    test('handles month overflow into next year', () {
      final exp = WarrantyTiming.expiryFrom(DateTime(2026, 11, 15), 3);
      expect(exp, DateTime(2027, 2, 15));
    });

    test('clamps day when target month is shorter', () {
      // 31. avgust + 6 meseci -> februar nema 31, pa 28. (2027 nije prestupna)
      final exp = WarrantyTiming.expiryFrom(DateTime(2026, 8, 31), 6);
      expect(exp, DateTime(2027, 2, 28));
    });

    test('preserves time of day', () {
      final exp =
          WarrantyTiming.expiryFrom(DateTime(2026, 1, 10, 14, 30), 12);
      expect(exp, DateTime(2027, 1, 10, 14, 30));
    });
  });

  group('WarrantyTiming.statusOf', () {
    final expiry = DateTime(2026, 6, 1);

    test('active when far from expiry', () {
      expect(WarrantyTiming.statusOf(expiry, now: DateTime(2026, 1, 1)),
          WarrantyStatus.active);
    });

    test('expiringSoon within 30 days', () {
      expect(WarrantyTiming.statusOf(expiry, now: DateTime(2026, 5, 20)),
          WarrantyStatus.expiringSoon);
    });

    test('expired on/after expiry', () {
      expect(WarrantyTiming.statusOf(expiry, now: DateTime(2026, 6, 1)),
          WarrantyStatus.expired);
      expect(WarrantyTiming.statusOf(expiry, now: DateTime(2026, 7, 1)),
          WarrantyStatus.expired);
    });

    test('exactly 30 days out counts as expiringSoon', () {
      expect(WarrantyTiming.statusOf(expiry, now: DateTime(2026, 5, 2)),
          WarrantyStatus.expiringSoon);
    });
  });

  test('daysLeft is negative once expired', () {
    final expiry = DateTime(2026, 6, 1);
    expect(WarrantyTiming.daysLeft(expiry, now: DateTime(2026, 5, 25)), 7);
    expect(WarrantyTiming.daysLeft(expiry, now: DateTime(2026, 6, 6)),
        lessThan(0));
  });
}
