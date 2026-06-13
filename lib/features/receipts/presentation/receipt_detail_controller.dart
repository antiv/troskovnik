import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/providers.dart';

/// Račun + prodavac + stavke za ekran detalja.
class ReceiptDetail {
  const ReceiptDetail({
    required this.receipt,
    required this.merchant,
    required this.items,
  });
  final ReceiptRow receipt;
  final MerchantRow merchant;
  final List<LineItemRow> items;
}

/// Reaktivni detalj jednog računa (osvežava se na izmene baze).
final receiptDetailProvider =
    StreamProvider.family<ReceiptDetail?, int>((ref, receiptId) async* {
  final db = await ref.watch(appDatabaseProvider.future);

  // Osvežava se na izmene računa I njegovih stavki (npr. dodela kategorije),
  // pošto watch na jednoj tabeli ne reaguje na promene u drugoj.
  final trigger = StreamGroup.merge<void>([
    (db.select(db.receipts)..where((r) => r.id.equals(receiptId)))
        .watch()
        .map((_) {}),
    (db.select(db.lineItems)..where((i) => i.receiptId.equals(receiptId)))
        .watch()
        .map((_) {}),
  ]);

  await for (final _ in trigger) {
    final receipts = await (db.select(db.receipts)
          ..where((r) => r.id.equals(receiptId)))
        .get();
    if (receipts.isEmpty) {
      yield null;
      continue;
    }
    final receipt = receipts.first;
    final merchant = await (db.select(db.merchants)
          ..where((m) => m.id.equals(receipt.merchantId)))
        .getSingle();
    final items = await (db.select(db.lineItems)
          ..where((i) => i.receiptId.equals(receiptId)))
        .get();
    yield ReceiptDetail(receipt: receipt, merchant: merchant, items: items);
  }
});
