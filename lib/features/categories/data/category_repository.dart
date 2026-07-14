import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../domain/category_models.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  Future<List<CategoryRow>> all() =>
      (_db.select(_db.categories)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  Stream<List<CategoryRow>> watchAll() =>
      (_db.select(_db.categories)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();

  Future<CategoryRow> create(String name, {String? color}) async {
    final maxSort = await _maxSortOrder();
    return _db.into(_db.categories).insertReturning(
          CategoriesCompanion.insert(
            name: name,
            color: Value(color),
            sortOrder: Value(maxSort + 1),
          ),
        );
  }

  Future<void> update(int id, {String? name, String? color, int? sortOrder}) =>
      (_db.update(_db.categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
      ));

  Future<void> delete(int id) => _db.transaction(() async {
        // FK setNull se ne emituje u šemu (vidi receipt_repository.delete),
        // pa ručno raskidamo reference da stavke ne ostanu „viseće".
        await (_db.update(_db.lineItems)
              ..where((i) => i.categoryId.equals(id)))
            .write(const LineItemsCompanion(categoryId: Value(null)));
        await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
      });

  Future<void> assignToItem(int itemId, int? categoryId) =>
      (_db.update(_db.lineItems)..where((i) => i.id.equals(itemId)))
          .write(LineItemsCompanion(
        categoryId: Value(categoryId),
      ));

  /// Dodeljuje kategoriju svim stavkama sa datim nazivom artikla (kroz sve
  /// račune) — analitika grupiše artikle po nazivu, pa promena iz nje važi
  /// za ceo artikal, ne za pojedinačnu stavku.
  Future<void> assignToItemsByName(String name, int? categoryId) =>
      (_db.update(_db.lineItems)..where((i) => i.name.equals(name)))
          .write(LineItemsCompanion(
        categoryId: Value(categoryId),
      ));

  Future<void> assignToReceipt(int receiptId, int? categoryId) =>
      (_db.update(_db.lineItems)..where((i) => i.receiptId.equals(receiptId)))
          .write(LineItemsCompanion(
        categoryId: Value(categoryId),
      ));

  Future<List<CategorySpending>> spendingByCategory(DateTime? since) async {
    final li = _db.lineItems;
    final c = _db.categories;
    final r = _db.receipts;
    final total = li.total.sum();
    final cnt = li.id.count();

    final notInvalid =
        r.fetchStatus.equalsValue(FetchStatus.invalid).not();
    Expression<bool> inPeriod;
    if (since != null) {
      inPeriod = r.pfrTime.isBiggerOrEqualValue(since) |
          (r.pfrTime.isNull() & r.createdAt.isBiggerOrEqualValue(since));
    } else {
      inPeriod = const Constant(true);
    }

    final q = _db.selectOnly(li).join([
      innerJoin(r, r.id.equalsExp(li.receiptId)),
      leftOuterJoin(c, c.id.equalsExp(li.categoryId)),
    ])
      ..addColumns([c.id, c.name, c.color, total, cnt])
      ..where(notInvalid & inPeriod & li.isUnparsed.equals(false))
      ..groupBy([c.id]);

    final rows = await q.get();
    return rows
        .map((row) => CategorySpending(
              categoryId: row.read(c.id) ?? 0,
              categoryName: row.read(c.name) ?? 'Nepoznato',
              color: row.read(c.color),
              totalMinor: row.read(total) ?? 0,
              itemCount: row.read(cnt) ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
  }

  Future<int> _maxSortOrder() async {
    final q = _db.selectOnly(_db.categories)
      ..addColumns([_db.categories.sortOrder]);
    final rows = await q.get();
    if (rows.isEmpty) return 0;
    return rows
        .map((r) => r.read(_db.categories.sortOrder) ?? 0)
        .reduce((a, b) => a > b ? a : b);
  }
}
