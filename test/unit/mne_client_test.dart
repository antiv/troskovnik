import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:troskovnik/features/source/data/mne_client.dart';
import 'package:troskovnik/features/source/domain/receipt_source.dart';

void main() {
  final client = MneClient();

  ParsedReceipt parse(Map<String, dynamic> json) => client.parse(
        RawPortalResponse(
          verificationUrl: 'https://mapr.tax.gov.me/ic/#/verify?iic=X',
          statusCode: 200,
          body: jsonEncode(json),
        ),
      );

  final base = <String, dynamic>{
    'iic': 'ABC',
    'seller': {'idNum': '02000001', 'name': 'Prodavac DOO'},
    'totalPrice': 12.5,
    'invoiceNumber': 'aa111aa111/1/2026/xx111xx111',
  };

  test('B2B: buyer TIN i naziv idu u zaglavlje', () {
    final p = parse({
      ...base,
      'buyer': {'idType': 'TIN', 'idNum': '02345678', 'name': 'Kupac DOO'},
    });
    expect(p.header!.buyerId, 'TIN:02345678');
    expect(p.header!.buyerName, 'Kupac DOO');
  });

  test('B2C: bez kupca', () {
    final p = parse(base);
    expect(p.header!.buyerId, isNull);
    expect(p.header!.buyerName, isNull);
  });
}
