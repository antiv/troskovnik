import 'package:workmanager/workmanager.dart';

import '../../../core/db/database.dart';
import '../../../core/db/db_key.dart';
import '../../source/data/taxcore_client.dart';
import 'receipt_repository.dart';
import 'refetch_service.dart';

/// Background re-fetch (sekcija 5, tačka 3): periodični workmanager task koji
/// obrađuje sve račune sa items_status = pendingServer i next_retry_at <= sada.
///
/// Sva logika prelaza je u [RefetchService] (testirano); ovde je samo glue.
class BackgroundRefetch {
  static const taskName = 'troskovnik.refetch.pending';
  static const _uniqueName = 'troskovnik.refetch.periodic';

  /// Pozvati iz main() pre runApp.
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  /// Zakaži periodični task (min. interval na Androidu je 15 min).
  static Future<void> schedulePeriodic() async {
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      taskName,
      frequency: const Duration(hours: 1),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancelAll() => Workmanager().cancelAll();
}

/// Entry point za background izolat. Mora biti top-level + @pragma.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != BackgroundRefetch.taskName) return true;

    final key = await DbKeyManager().getOrCreateKey();
    final db = AppDatabase.encrypted(key);
    try {
      final service = RefetchService(TaxCoreClient(), ReceiptRepository(db));
      await service.processDue();
      return true;
    } finally {
      await db.close();
    }
  });
}
