import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/db/db_recovery.dart';
import 'features/receipts/data/background_refetch.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ključ baze mora da postoji PRE zakazivanja background taska: WorkManager
  // prvi periodični run pušta bez odlaganja, pa bi oba izolata mogla da
  // naprave svaki svoj ključ i trajno zaključaju bazu (vidi ensureDatabaseKey).
  await ensureDatabaseKey();
  // Background re-fetch za stavke koje još nisu na serveru (sekcija 5).
  await BackgroundRefetch.initialize();
  await BackgroundRefetch.schedulePeriodic();
  runApp(const ProviderScope(child: TroskovnikApp()));
}
