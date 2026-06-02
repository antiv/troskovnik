// Alat za hvatanje REALNIH odgovora TaxCore portala kao test fixture-a.
//
// Sekcija 3 (bold) i sekcija 11 instrukcije.md: parser se gradi i testira nad
// realnim odgovorima, jer se tačan oblik (HTML vs JSON, nazivi polja) mora
// potvrditi empirijski. Ovaj alat dohvati verifikacionu stranicu i (best-effort)
// izdvojene stavke za dati URL i snimi ih u test/fixtures/<label>.*.
//
// Upotreba (kroz FVM):
//   fvm dart run tool/capture_fixtures.dart <label> "<verification_url>"
//
// Primeri label-a (uhvatiti za sva stanja iz sekcije 9):
//   complete, header_only, pending_server, invalid, journal_only
//
// Snima:
//   test/fixtures/<label>.page.html
//   test/fixtures/<label>.specifications.txt   (ako endpoint nešto vrati)
//   test/fixtures/<label>.meta.json            (status, content-type, url)

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

const _specificationsPath = '/specifications';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'Upotreba: fvm dart run tool/capture_fixtures.dart <label> "<url>"',
    );
    exitCode = 64; // EX_USAGE
    return;
  }
  final label = args[0];
  final url = args[1];

  final dir = Directory('test/fixtures');
  await dir.create(recursive: true);

  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    headers: const {'User-Agent': 'Troskovnik/1.0 (fixture capture)'},
    validateStatus: (_) => true, // snimi i 4xx/5xx
  ));

  stdout.writeln('Dohvatam stranicu: $url');
  final page = await dio.get<String>(
    url,
    options: Options(responseType: ResponseType.plain),
  );
  await File('${dir.path}/$label.page.html')
      .writeAsString(page.data ?? '');
  stdout.writeln('  -> $label.page.html (${(page.data ?? '').length} B, '
      'status ${page.statusCode})');

  // invoiceNumber i token (GUID) su u inline <script> stranice — NE vl token.
  final pageBody = page.data ?? '';
  final invoiceNumber =
      RegExp(r"InvoiceNumber\(\s*'([^']+)'\s*\)").firstMatch(pageBody)?.group(1);
  final token =
      RegExp(r"\.Token\(\s*'([^']+)'\s*\)").firstMatch(pageBody)?.group(1);

  String? specsStatus;
  try {
    final base = Uri.parse(url);
    final specsUrl =
        base.replace(path: _specificationsPath, query: '').toString();
    stdout.writeln('Probam izdvojene stavke: $specsUrl '
        '(invoiceNumber=$invoiceNumber)');
    final specs = await dio.post<String>(
      specsUrl,
      data: {'invoiceNumber': invoiceNumber, 'token': token},
      options: Options(
        responseType: ResponseType.plain,
        contentType: Headers.formUrlEncodedContentType,
        headers: const {'X-Requested-With': 'XMLHttpRequest'},
      ),
    );
    specsStatus = '${specs.statusCode}';
    if ((specs.data ?? '').isNotEmpty) {
      await File('${dir.path}/$label.specifications.txt')
          .writeAsString(specs.data!);
      stdout.writeln(
          '  -> $label.specifications.txt (${specs.data!.length} B, '
          'status ${specs.statusCode})');
    } else {
      stdout.writeln('  -> stavke prazne (status ${specs.statusCode})');
    }
  } catch (e) {
    specsStatus = 'error: $e';
    stdout.writeln('  -> stavke nedostupne: $e');
  }

  final meta = {
    'label': label,
    'url': url,
    'pageStatus': page.statusCode,
    'pageContentType': page.headers.value('content-type'),
    'specificationsStatus': specsStatus,
    'capturedAt': DateTime.now().toIso8601String(),
  };
  await File('${dir.path}/$label.meta.json')
      .writeAsString(const JsonEncoder.withIndent('  ').convert(meta));
  stdout.writeln('  -> $label.meta.json');
  stdout.writeln('Gotovo. Pregledaj fajlove i potvrdi strukturu pre parsera.');
}
