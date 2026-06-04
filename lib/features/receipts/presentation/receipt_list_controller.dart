import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

enum ReceiptSort { date, merchant, amount }

/// Spoj računa + prodavca za prikaz u listi.
class ReceiptListItem {
  const ReceiptListItem({required this.receipt, required this.merchant});
  final ReceiptRow receipt;
  final MerchantRow merchant;
}

/// Filter po tipu (poslovni/privatni/svi) — #8.
enum ReceiptKindFilter { all, business, personal }

/// Parametri pretrage/sortiranja/filtriranja liste.
class ReceiptQuery {
  const ReceiptQuery({
    this.search = '',
    this.sort = ReceiptSort.date,
    this.kind = ReceiptKindFilter.all,
  });
  final String search;
  final ReceiptSort sort;
  final ReceiptKindFilter kind;

  ReceiptQuery copyWith(
          {String? search, ReceiptSort? sort, ReceiptKindFilter? kind}) =>
      ReceiptQuery(
        search: search ?? this.search,
        sort: sort ?? this.sort,
        kind: kind ?? this.kind,
      );
}

/// Drži parametre pretrage/sortiranja/filtriranja liste računa.
class ReceiptQueryNotifier extends Notifier<ReceiptQuery> {
  @override
  ReceiptQuery build() => const ReceiptQuery();

  void setSearch(String search) => state = state.copyWith(search: search);
  void setSort(ReceiptSort sort) => state = state.copyWith(sort: sort);
  void setKind(ReceiptKindFilter kind) => state = state.copyWith(kind: kind);
}

final receiptQueryProvider =
    NotifierProvider<ReceiptQueryNotifier, ReceiptQuery>(
        ReceiptQueryNotifier.new);

/// Lista računa iz baze, reaktivna na izmene + na [receiptQueryProvider].
/// Pretraga ide po nazivu prodavca i po nazivu artikla (sekcija 7).
final receiptListProvider =
    StreamProvider<List<ReceiptListItem>>((ref) async* {
  final db = await ref.watch(appDatabaseProvider.future);
  final query = ref.watch(receiptQueryProvider);

  final select = db.select(db.receipts).join([
    innerJoin(db.merchants, db.merchants.id.equalsExp(db.receipts.merchantId)),
  ]);

  switch (query.kind) {
    case ReceiptKindFilter.business:
      select.where(db.receipts.isBusiness.equals(true));
    case ReceiptKindFilter.personal:
      select.where(db.receipts.isBusiness.equals(false));
    case ReceiptKindFilter.all:
      break;
  }

  switch (query.sort) {
    case ReceiptSort.date:
      select.orderBy([
        OrderingTerm(expression: db.receipts.pfrTime, mode: OrderingMode.desc),
        OrderingTerm(
            expression: db.receipts.createdAt, mode: OrderingMode.desc),
      ]);
    case ReceiptSort.merchant:
      select.orderBy([OrderingTerm(expression: db.merchants.name)]);
    case ReceiptSort.amount:
      select.orderBy([
        OrderingTerm(
            expression: db.receipts.totalAmount, mode: OrderingMode.desc),
      ]);
  }

  yield* select.watch().asyncMap((rows) async {
    var items = rows
        .map((r) => ReceiptListItem(
              receipt: r.readTable(db.receipts),
              merchant: r.readTable(db.merchants),
            ))
        .toList();

    final term = query.search.trim().toLowerCase();
    if (term.isNotEmpty) {
      // Računi čiji prodavac ili neki artikal odgovara terminu.
      final matchingByItem = await (db.selectOnly(db.lineItems, distinct: true)
            ..addColumns([db.lineItems.receiptId])
            ..where(db.lineItems.name.lower().like('%$term%')))
          .map((row) => row.read(db.lineItems.receiptId))
          .get();
      final itemMatchIds = matchingByItem.whereType<int>().toSet();

      items = items
          .where((i) =>
              i.merchant.name.toLowerCase().contains(term) ||
              itemMatchIds.contains(i.receipt.id))
          .toList();
    }
    return items;
  });
});
