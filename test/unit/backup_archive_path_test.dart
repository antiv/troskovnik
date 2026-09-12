import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:troskovnik/features/backup/data/backup_service.dart';

void main() {
  test('zadržava samo ime fajla', () {
    expect(safeArchiveFileName('images/receipts/racun-1.jpg'), 'racun-1.jpg');
    expect(
      safeArchiveFileName('images/warranty_proofs/garancija.png'),
      'garancija.png',
    );
  });

  test('zip slip ne izlazi iz ciljnog direktorijuma', () {
    final name =
        safeArchiveFileName('images/receipts/../../troskovnik.db.enc')!;

    expect(p.split(name), hasLength(1));
    expect(
      p.join('/data/app_flutter/images/receipts', name),
      '/data/app_flutter/images/receipts/troskovnik.db.enc',
    );
  });

  test('putanje u Windows stilu se takođe svode na ime fajla', () {
    expect(
      safeArchiveFileName(r'images\receipts\..\..\troskovnik.db.enc'),
      'troskovnik.db.enc',
    );
  });

  test('unosi bez upotrebljivog imena se preskaču', () {
    expect(safeArchiveFileName(''), isNull);
    expect(safeArchiveFileName('images/receipts/..'), isNull);
    expect(safeArchiveFileName('.'), isNull);
  });
}
