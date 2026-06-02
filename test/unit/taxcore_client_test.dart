import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:troskovnik/features/source/data/taxcore_client.dart';
import 'package:troskovnik/features/source/domain/receipt_source.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late TaxCoreClient client;
  const url = 'https://suf.purs.gov.rs/v/?vl=TOKEN';

  setUp(() {
    dio = _MockDio();
    client = TaxCoreClient(dio: dio);
  });

  Response<String> resp(String body, {int status = 200}) => Response<String>(
        requestOptions: RequestOptions(path: url),
        statusCode: status,
        data: body,
      );

  test('fetch GETs page and POSTs specs with invoiceNumber+token from page',
      () async {
    const page = "<html><script>"
        "viewModel.InvoiceNumber('INV-1');viewModel.Token('GUID-1');"
        "</script><pre>journal</pre></html>";

    when(() => dio.get<String>(url, options: any(named: 'options')))
        .thenAnswer((_) async => resp(page));
    when(() => dio.post<String>(any(),
            data: any(named: 'data'), options: any(named: 'options')))
        .thenAnswer((_) async => resp('{"success":false}'));

    final raw = await client.fetch(url);
    expect(raw.body, page);
    expect(raw.specificationsBody, '{"success":false}');

    final captured = verify(() => dio.post<String>(any(),
        data: captureAny(named: 'data'),
        options: any(named: 'options'))).captured;
    expect(captured.single, {'invoiceNumber': 'INV-1', 'token': 'GUID-1'});
  });

  test('connection error -> NoNetworkException', () async {
    when(() => dio.get<String>(url, options: any(named: 'options'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: url),
        type: DioExceptionType.connectionError,
      ),
    );
    expect(() => client.fetch(url), throwsA(isA<NoNetworkException>()));
  });

  test('bad response -> PortalUnavailableException', () async {
    when(() => dio.get<String>(url, options: any(named: 'options'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: url),
        type: DioExceptionType.badResponse,
        message: 'boom',
      ),
    );
    expect(
        () => client.fetch(url), throwsA(isA<PortalUnavailableException>()));
  });
}
