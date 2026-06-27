import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';

class BackupException implements Exception {
  const BackupException(this.code);
  final String code; // 'corrupt' | 'io_error'
}

class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static final _stamp = DateFormat('yyyyMMdd');

  Future<String> exportToZip() async {
    final categories = await _db.select(_db.categories).get();
    final merchants = await _db.select(_db.merchants).get();
    final receipts = await _db.select(_db.receipts).get();
    final lineItems = await _db.select(_db.lineItems).get();
    final warranties = await _db.select(_db.warranties).get();

    final archive = Archive();

    // Collect and archive receipt images.
    final receiptImageZipPaths = <int, String?>{};
    for (final r in receipts) {
      if (r.imagePath != null) {
        final file = File(r.imagePath!);
        if (file.existsSync()) {
          final rel = 'images/receipts/${p.basename(r.imagePath!)}';
          receiptImageZipPaths[r.id] = rel;
          final bytes = file.readAsBytesSync();
          archive.addFile(ArchiveFile(rel, bytes.length, bytes));
        } else {
          receiptImageZipPaths[r.id] = null;
        }
      } else {
        receiptImageZipPaths[r.id] = null;
      }
    }

    // Collect and archive warranty proof images.
    final warrantyImageZipPaths = <int, String?>{};
    for (final w in warranties) {
      if (w.proofImagePath != null) {
        final file = File(w.proofImagePath!);
        if (file.existsSync()) {
          final rel = 'images/warranty_proofs/${p.basename(w.proofImagePath!)}';
          warrantyImageZipPaths[w.id] = rel;
          final bytes = file.readAsBytesSync();
          archive.addFile(ArchiveFile(rel, bytes.length, bytes));
        } else {
          warrantyImageZipPaths[w.id] = null;
        }
      } else {
        warrantyImageZipPaths[w.id] = null;
      }
    }

    final info = await PackageInfo.fromPlatform();
    final manifest = {
      'version': 1,
      'appVersion': info.version,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': [
        for (final c in categories)
          {
            'id': c.id,
            'name': c.name,
            'color': c.color,
            'sortOrder': c.sortOrder,
            'isDefault': c.isDefault,
            'createdAt': c.createdAt.toIso8601String(),
          },
      ],
      'merchants': [
        for (final m in merchants)
          {
            'id': m.id,
            'tin': m.tin,
            'name': m.name,
            'locationName': m.locationName,
            'address': m.address,
            'firstSeen': m.firstSeen.toIso8601String(),
          },
      ],
      'receipts': [
        for (final r in receipts)
          {
            'id': r.id,
            'merchantId': r.merchantId,
            'invoiceNumber': r.invoiceNumber,
            'pfrNumber': r.pfrNumber,
            'buyerId': r.buyerId,
            'pfrTime': r.pfrTime?.toIso8601String(),
            'sdcTime': r.sdcTime?.toIso8601String(),
            'invoiceCounter': r.invoiceCounter,
            'invoiceType': r.invoiceType.index,
            'transactionType': r.transactionType.index,
            'totalAmount': r.totalAmount,
            'paymentMethod': r.paymentMethod,
            'paymentsJson': r.paymentsJson,
            'taxJson': r.taxJson,
            'verificationUrl': r.verificationUrl,
            'token': r.token,
            'journalText': r.journalText,
            'fetchStatus': r.fetchStatus.index,
            'itemsStatus': r.itemsStatus.index,
            'itemsSource': r.itemsSource.index,
            'retryCount': r.retryCount,
            'nextRetryAt': r.nextRetryAt?.toIso8601String(),
            'isBusiness': r.isBusiness,
            'imagePath': receiptImageZipPaths[r.id],
            'note': r.note,
            'createdAt': r.createdAt.toIso8601String(),
            'updatedAt': r.updatedAt.toIso8601String(),
          },
      ],
      'lineItems': [
        for (final li in lineItems)
          {
            'id': li.id,
            'receiptId': li.receiptId,
            'name': li.name,
            'quantity': li.quantity,
            'unit': li.unit,
            'unitPrice': li.unitPrice,
            'total': li.total,
            'taxLabel': li.taxLabel,
            'taxRate': li.taxRate,
            'source': li.source.index,
            'isUnparsed': li.isUnparsed,
            'categoryId': li.categoryId,
          },
      ],
      'warranties': [
        for (final w in warranties)
          {
            'id': w.id,
            'receiptId': w.receiptId,
            'lineItemId': w.lineItemId,
            'title': w.title,
            'purchaseDate': w.purchaseDate.toIso8601String(),
            'durationMonths': w.durationMonths,
            'expiryDate': w.expiryDate.toIso8601String(),
            'note': w.note,
            'proofImagePath': warrantyImageZipPaths[w.id],
            'createdAt': w.createdAt.toIso8601String(),
          },
      ],
    };

    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    final encoded = ZipEncoder().encode(archive);

    final dir = await getTemporaryDirectory();
    final name = 'troskovnik-backup-${_stamp.format(DateTime.now())}.zip';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(encoded);
    return file.path;
  }

  Future<void> importFromZip(String zipPath) async {
    final bytes = File(zipPath).readAsBytesSync();
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupException('corrupt');
    }

    ArchiveFile? manifestEntry;
    for (final f in archive) {
      if (f.name == 'manifest.json') {
        manifestEntry = f;
        break;
      }
    }
    if (manifestEntry == null) throw const BackupException('corrupt');

    Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestEntry.content))
          as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('corrupt');
    }
    if (manifest['version'] != 1) throw const BackupException('corrupt');

    final appDocDir = (await getApplicationDocumentsDirectory()).path;

    try {
      await _db.transaction(() async {
        // Delete in reverse FK order to avoid constraint violations.
        await _db.delete(_db.warranties).go();
        await _db.delete(_db.lineItems).go();
        await _db.delete(_db.receipts).go();
        await _db.delete(_db.merchants).go();
        await _db.delete(_db.categories).go();

        for (final c in manifest['categories'] as List<dynamic>) {
          final j = c as Map<String, dynamic>;
          await _db.into(_db.categories).insert(
                CategoriesCompanion(
                  id: Value(j['id'] as int),
                  name: Value(j['name'] as String),
                  color: Value(j['color'] as String?),
                  sortOrder: Value(j['sortOrder'] as int),
                  isDefault: Value(j['isDefault'] as bool),
                  createdAt:
                      Value(DateTime.parse(j['createdAt'] as String)),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        for (final m in manifest['merchants'] as List<dynamic>) {
          final j = m as Map<String, dynamic>;
          await _db.into(_db.merchants).insert(
                MerchantsCompanion(
                  id: Value(j['id'] as int),
                  tin: Value(j['tin'] as String),
                  name: Value(j['name'] as String),
                  locationName: Value(j['locationName'] as String?),
                  address: Value(j['address'] as String?),
                  firstSeen:
                      Value(DateTime.parse(j['firstSeen'] as String)),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        for (final r in manifest['receipts'] as List<dynamic>) {
          final j = r as Map<String, dynamic>;
          final zipImagePath = j['imagePath'] as String?;
          final imagePath = zipImagePath == null
              ? null
              : p.join(appDocDir, zipImagePath);
          await _db.into(_db.receipts).insert(
                ReceiptsCompanion(
                  id: Value(j['id'] as int),
                  merchantId: Value(j['merchantId'] as int),
                  invoiceNumber: Value(j['invoiceNumber'] as String?),
                  pfrNumber: Value(j['pfrNumber'] as String?),
                  buyerId: Value(j['buyerId'] as String?),
                  pfrTime: Value(j['pfrTime'] == null
                      ? null
                      : DateTime.parse(j['pfrTime'] as String)),
                  sdcTime: Value(j['sdcTime'] == null
                      ? null
                      : DateTime.parse(j['sdcTime'] as String)),
                  invoiceCounter: Value(j['invoiceCounter'] as String?),
                  invoiceType: Value(
                      InvoiceType.values[j['invoiceType'] as int]),
                  transactionType: Value(
                      TransactionType.values[j['transactionType'] as int]),
                  totalAmount: Value(j['totalAmount'] as int),
                  paymentMethod: Value(j['paymentMethod'] as String?),
                  paymentsJson: Value(j['paymentsJson'] as String?),
                  taxJson: Value(j['taxJson'] as String?),
                  verificationUrl: Value(j['verificationUrl'] as String),
                  token: Value(j['token'] as String?),
                  journalText: Value(j['journalText'] as String?),
                  fetchStatus: Value(
                      FetchStatus.values[j['fetchStatus'] as int]),
                  itemsStatus: Value(
                      ItemsStatus.values[j['itemsStatus'] as int]),
                  itemsSource: Value(
                      ItemsSource.values[j['itemsSource'] as int]),
                  retryCount: Value(j['retryCount'] as int),
                  nextRetryAt: Value(j['nextRetryAt'] == null
                      ? null
                      : DateTime.parse(j['nextRetryAt'] as String)),
                  isBusiness: Value(j['isBusiness'] as bool),
                  imagePath: Value(imagePath),
                  note: Value(j['note'] as String?),
                  createdAt:
                      Value(DateTime.parse(j['createdAt'] as String)),
                  updatedAt:
                      Value(DateTime.parse(j['updatedAt'] as String)),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        for (final li in manifest['lineItems'] as List<dynamic>) {
          final j = li as Map<String, dynamic>;
          await _db.into(_db.lineItems).insert(
                LineItemsCompanion(
                  id: Value(j['id'] as int),
                  receiptId: Value(j['receiptId'] as int),
                  name: Value(j['name'] as String),
                  quantity:
                      Value((j['quantity'] as num).toDouble()),
                  unit: Value(j['unit'] as String?),
                  unitPrice: Value(j['unitPrice'] as int),
                  total: Value(j['total'] as int),
                  taxLabel: Value(j['taxLabel'] as String?),
                  taxRate: Value(j['taxRate'] == null
                      ? null
                      : (j['taxRate'] as num).toDouble()),
                  source: Value(
                      ItemsSource.values[j['source'] as int]),
                  isUnparsed: Value(j['isUnparsed'] as bool),
                  categoryId: Value(j['categoryId'] as int?),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        for (final w in manifest['warranties'] as List<dynamic>) {
          final j = w as Map<String, dynamic>;
          final zipProofPath = j['proofImagePath'] as String?;
          // Warranty proofs live in {appDocDir}/warranty_proofs/ by convention.
          final proofImagePath = zipProofPath == null
              ? null
              : p.join(appDocDir, 'warranty_proofs',
                  p.basename(zipProofPath));
          await _db.into(_db.warranties).insert(
                WarrantiesCompanion(
                  id: Value(j['id'] as int),
                  receiptId: Value(j['receiptId'] as int),
                  lineItemId: Value(j['lineItemId'] as int?),
                  title: Value(j['title'] as String),
                  purchaseDate:
                      Value(DateTime.parse(j['purchaseDate'] as String)),
                  durationMonths: Value(j['durationMonths'] as int),
                  expiryDate:
                      Value(DateTime.parse(j['expiryDate'] as String)),
                  note: Value(j['note'] as String?),
                  proofImagePath: Value(proofImagePath),
                  createdAt:
                      Value(DateTime.parse(j['createdAt'] as String)),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      });
    } catch (e) {
      if (e is BackupException) rethrow;
      throw const BackupException('io_error');
    }

    // Extract image files outside the transaction (non-fatal on error).
    final receiptsImgDir =
        Directory(p.join(appDocDir, 'images', 'receipts'));
    if (!receiptsImgDir.existsSync()) {
      receiptsImgDir.createSync(recursive: true);
    }
    final warrantyProofsDir =
        Directory(p.join(appDocDir, 'warranty_proofs'));
    if (!warrantyProofsDir.existsSync()) {
      warrantyProofsDir.createSync(recursive: true);
    }

    for (final entry in archive) {
      if (!entry.isFile) continue;
      try {
        final content = entry.content;
        if (entry.name.startsWith('images/receipts/')) {
          final dest = File(p.join(appDocDir, entry.name));
          await dest.writeAsBytes(content);
        } else if (entry.name.startsWith('images/warranty_proofs/')) {
          final dest = File(
              p.join(appDocDir, 'warranty_proofs', p.basename(entry.name)));
          await dest.writeAsBytes(content);
        }
      } catch (_) {
        // Skip images that fail; the DB row will have a dangling path.
      }
    }
  }
}
