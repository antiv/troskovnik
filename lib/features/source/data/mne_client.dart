import 'dart:convert';

import 'package:dio/dio.dart';

import '../domain/receipt_source.dart';
import '../../../core/db/enums.dart';

/// Klijent za crnogorski fiskalni portal (mapr.tax.gov.me).
///
/// URL format: https://mapr.tax.gov.me/ic/#/verify?iic=...&tin=...&crtd=...
/// API: POST /ic/api/verifyInvoice sa form-data iic/tin/dateTimeCreated.
/// Odgovor: JSON s `seller`, `items[]`, `paymentMethod[]`, `totalPrice` (EUR).
class MneClient implements ReceiptSource {
  MneClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {
                'User-Agent': 'Troskovnik/1.0 (+fiscal receipt verifier)',
                'Origin': 'https://mapr.tax.gov.me',
                'Referer': 'https://mapr.tax.gov.me/ic/',
              },
            ));

  static const _apiUrl = 'https://mapr.tax.gov.me/ic/api/verifyInvoice';

  final Dio _dio;

  @override
  Future<RawPortalResponse> fetch(String verificationUrl) async {
    final params = _fragmentParams(Uri.parse(verificationUrl).fragment);
    final iic = params['iic'] ?? '';
    final tin = params['tin'] ?? '';
    final crtd = params['crtd'] ?? '';

    try {
      final resp = await _dio.post<String>(
        _apiUrl,
        data: {'iic': iic, 'dateTimeCreated': crtd, 'tin': tin},
        options: Options(
          responseType: ResponseType.plain,
          contentType: Headers.formUrlEncodedContentType,
          headers: const {'Accept': 'application/json'},
        ),
      );
      return RawPortalResponse(
        verificationUrl: verificationUrl,
        statusCode: resp.statusCode ?? 0,
        body: resp.data ?? '',
        contentType: 'application/json',
      );
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
          throw const NoNetworkException();
        default:
          throw PortalUnavailableException(e.message ?? 'Portal error');
      }
    }
  }

  @override
  ParsedReceipt parse(RawPortalResponse raw) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw.body) as Map<String, dynamic>;
    } catch (_) {
      return _pending;
    }

    if (json['iic'] == null) return _invalid;

    final seller = json['seller'] as Map<String, dynamic>?;
    final tin = seller?['idNum'] as String? ?? '';
    final name = (seller?['name'] as String? ?? '').trim();

    final totalEur = (json['totalPrice'] as num?)?.toDouble() ?? 0.0;

    DateTime? pfrTime;
    final dtStr = json['dateTimeCreated'] as String?;
    if (dtStr != null) pfrTime = DateTime.tryParse(dtStr);

    final invoiceNumber = json['invoiceNumber'] as String?;

    final invoiceType = json['invoiceType'] as String? ?? 'INVOICE';
    final transactionType = invoiceType == 'CORRECTIVE'
        ? TransactionType.refund
        : TransactionType.sale;

    // Načini plaćanja
    final rawPayments = (json['paymentMethod'] as List<dynamic>?) ?? [];
    String? primaryPayment;
    final paymentsMap = <String, int>{};
    for (final pm in rawPayments) {
      final m = pm as Map<String, dynamic>;
      final typeCode = m['typeCode'] as String? ?? 'OTHER';
      final amount = (m['amount'] as num?)?.toDouble() ?? 0.0;
      final label = _paymentLabel(typeCode);
      primaryPayment ??= label;
      paymentsMap[label] = (paymentsMap[label] ?? 0) + _toCents(amount);
    }

    final sign = transactionType == TransactionType.refund ? -1 : 1;

    final header = ReceiptHeader(
      merchantTin: tin,
      merchantName: name,
      pfrNumber: invoiceNumber,
      pfrTime: pfrTime,
      totalAmount: sign * _toCents(totalEur),
      transactionType: transactionType,
      paymentMethod: primaryPayment,
      paymentsJson: paymentsMap.isEmpty ? null : jsonEncode(paymentsMap),
    );

    // Stavke — CG vraća strukturirane podatke direktno (nema žurnal parsiranja).
    final rawItems = (json['items'] as List<dynamic>?) ?? [];
    if (rawItems.isNotEmpty) {
      final items = rawItems.map((item) {
        final m = item as Map<String, dynamic>;
        final itemName = (m['name'] as String? ?? '').trim();
        final qty = (m['quantity'] as num?)?.toDouble() ?? 1.0;
        final unitPrice = (m['unitPriceAfterVat'] as num?)?.toDouble() ?? 0.0;
        final total = (m['priceAfterVat'] as num?)?.toDouble() ?? 0.0;
        final vatRate = (m['vatRate'] as num?)?.toDouble();
        final unit = m['unit'] as String?;
        return ParsedLineItem(
          name: itemName,
          quantity: qty,
          unit: unit,
          unitPrice: _toCents(unitPrice),
          total: sign * _toCents(total),
          taxRate: vatRate,
          source: ItemsSource.specifications,
        );
      }).toList();

      return ParsedReceipt(
        fetchStatus: FetchStatus.complete,
        itemsStatus: ItemsStatus.fromSpecifications,
        itemsSource: ItemsSource.specifications,
        header: header,
        items: items,
      );
    }

    return ParsedReceipt(
      fetchStatus: FetchStatus.headerOnly,
      itemsStatus: ItemsStatus.pendingServer,
      itemsSource: ItemsSource.none,
      header: header,
    );
  }

  static int _toCents(double eur) => (eur * 100).round();

  static String _paymentLabel(String typeCode) => switch (typeCode) {
        'BANKNOTE' => 'Готовина',
        'CARD' || 'BUSINESSCARD' => 'Платна картица',
        'ACCOUNT' || 'CURRENT_ACCOUNT' => 'Пренос на рачун',
        'SVOUCHER' || 'BEARER_VOUCHER' => 'Ваучер',
        _ => 'Друго',
      };

  static Map<String, String> _fragmentParams(String fragment) {
    final q = fragment.indexOf('?');
    if (q < 0) return {};
    return Uri.splitQueryString(fragment.substring(q + 1));
  }

  static const _pending = ParsedReceipt(
    fetchStatus: FetchStatus.pending,
    itemsStatus: ItemsStatus.pendingServer,
    itemsSource: ItemsSource.none,
  );

  static const _invalid = ParsedReceipt(
    fetchStatus: FetchStatus.invalid,
    itemsStatus: ItemsStatus.none,
    itemsSource: ItemsSource.none,
  );
}
