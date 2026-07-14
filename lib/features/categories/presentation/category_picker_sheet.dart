import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../data/category_providers.dart';
import 'category_tag.dart';

class CategoryPickerSheet extends ConsumerWidget {
  const CategoryPickerSheet({super.key, this.currentCategoryId});

  final int? currentCategoryId;

  /// Sentinel za izbor „Bez kategorije" — razlikuje se od `null` koji znači
  /// da je korisnik odustao (zatvorio sheet bez izbora). Bezbedan je jer
  /// SQLite id-jevi kategorija kreću od 1.
  static const int noneId = 0;

  /// Vraća id izabrane kategorije, [noneId] za „Bez kategorije",
  /// ili `null` ako je korisnik odustao.
  static Future<int?> show(BuildContext context, {int? currentCategoryId}) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CategoryPickerSheet(currentCategoryId: currentCategoryId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: categoriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Center(child: Text('${l10n.errGeneric}\n$e')),
          data: (categories) => ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.clear_all),
                title: Text(l10n.categoryNone),
                selected: currentCategoryId == null,
                onTap: () => Navigator.pop(context, noneId),
              ),
              for (final cat in categories)
                ListTile(
                  leading: CategoryTag(color: cat.color),
                  title: Text(cat.name),
                  selected: cat.id == currentCategoryId,
                  trailing: cat.id == currentCategoryId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, cat.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
