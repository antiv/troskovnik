import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';
import '../domain/category_models.dart';
import 'category_repository.dart';

final categoryRepositoryProvider =
    FutureProvider<CategoryRepository>((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return CategoryRepository(db);
});

final categoriesProvider = StreamProvider<List<CategoryRow>>((ref) async* {
  final repo = await ref.watch(categoryRepositoryProvider.future);
  yield* repo.watchAll();
});

final categorySpendingProvider =
    FutureProvider.family<List<CategorySpending>, DateTime?>(
        (ref, since) async {
  final repo = await ref.watch(categoryRepositoryProvider.future);
  return repo.spendingByCategory(since);
});
