import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import 'backup_service.dart';

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return BackupService(db);
});
