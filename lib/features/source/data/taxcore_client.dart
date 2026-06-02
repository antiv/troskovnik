import 'package:dio/dio.dart';

import '../domain/receipt_source.dart';
import 'taxcore_parser.dart';

/// Mrežni klijent ka TaxCore portalu (`suf.purs.gov.rs`).
///
/// Tok (sekcija 3): GET verifikacione stranice → (ako stranica izlaže) zahtev
/// za izdvojene stavke (specifications). TAČAN endpoint/format stavki je
/// otvoreno pitanje (sekcija 11 #1) i potvrđuje se nad realnim fixture-ima;
/// zato je putanja izdvojena u konstantu i poziv je „best-effort" — ako ne
/// uspe, padamo na parsiranje žurnala.
class TaxCoreClient implements ReceiptSource {
  TaxCoreClient({Dio? dio, TaxCoreParser? parser})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              followRedirects: true,
              headers: const {
                'User-Agent': 'Troskovnik/1.0 (+fiscal receipt verifier)',
              },
            )),
        _parser = parser ?? const TaxCoreParser();

  /// Putanja koju verifikaciona stranica koristi za izdvojene stavke.
  /// POTVRDITI nad realnim odgovorom (sekcija 11 #1).
  static const specificationsPath = '/specifications';

  final Dio _dio;
  final TaxCoreParser _parser;

  @override
  Future<RawPortalResponse> fetch(String verificationUrl) async {
    try {
      final pageResp = await _dio.get<String>(
        verificationUrl,
        options: Options(responseType: ResponseType.plain),
      );

      String? specsBody;
      // Best-effort: probaj specifications endpoint. Ako padne, ostaje null i
      // parser pada na žurnal.
      try {
        final base = Uri.parse(verificationUrl);
        final token = base.queryParameters['vl'];
        final specsResp = await _dio.post<String>(
          base.replace(path: specificationsPath, query: '').toString(),
          data: {'invoiceNumber': token},
          options: Options(responseType: ResponseType.plain),
        );
        if (specsResp.statusCode == 200) {
          specsBody = specsResp.data;
        }
      } catch (_) {
        // Stavke nisu (još) dostupne ovim putem — ignoriši, žurnal je fallback.
      }

      return RawPortalResponse(
        verificationUrl: verificationUrl,
        statusCode: pageResp.statusCode ?? 0,
        body: pageResp.data ?? '',
        specificationsBody: specsBody,
        contentType: pageResp.headers.value('content-type'),
      );
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
          throw const NoNetworkException();
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.badResponse:
        case DioExceptionType.badCertificate:
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
          throw PortalUnavailableException(e.message ?? 'Portal error');
      }
    }
  }

  @override
  ParsedReceipt parse(RawPortalResponse raw) => _parser.parse(raw);
}
