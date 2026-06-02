import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/receipts/data/background_refetch.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Background re-fetch za stavke koje još nisu na serveru (sekcija 5).
  await BackgroundRefetch.initialize();
  await BackgroundRefetch.schedulePeriodic();
  runApp(const ProviderScope(child: TroskovnikApp()));
}
