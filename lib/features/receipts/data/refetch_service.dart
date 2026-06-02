import '../../source/domain/receipt_source.dart';
import 'receipt_repository.dart';

/// Orkestrira re-fetch računa kojima stavke još nisu stigle (sekcija 5).
///
/// Koristi se i iz background taska (workmanager) i iz ručnog „Osveži sada".
class RefetchService {
  RefetchService(this._source, this._repository);

  final ReceiptSource _source;
  final ReceiptRepository _repository;

  /// Re-fetch jednog računa po id-u. Vraća true ako su stavke uspešno dopunjene.
  Future<bool> refetchOne(int receiptId, {DateTime? now}) async {
    final row = await _repository.findById(receiptId);
    if (row == null) return false;

    try {
      final raw = await _source.fetch(row.verificationUrl);
      final parsed = _source.parse(raw);
      await _repository.applyRefetch(receiptId, parsed, now: now);
      return parsed.items.isNotEmpty;
    } on ReceiptSourceException {
      // Mreža/portal — ostavi zapis, pokušaj kasnije (zakazivanje radi caller).
      return false;
    }
  }

  /// Obradi sve račune čiji je re-fetch dospeo. Vraća broj uspešno dopunjenih.
  Future<int> processDue({DateTime? now}) async {
    final due = await _repository.dueForRefetch(now: now);
    var completed = 0;
    for (final row in due) {
      final ok = await refetchOne(row.id, now: now);
      if (ok) completed++;
    }
    return completed;
  }
}
