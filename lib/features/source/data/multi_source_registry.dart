import '../domain/receipt_source.dart';
import 'mne_client.dart';
import 'taxcore_client.dart';

/// Bira pravi klijent na osnovu hosta verifikacionog URL-a.
///
/// TaxCore (Srbija + RS): suf.purs.gov.rs, suf.poreskaupravars.org
/// Crna Gora: mapr.tax.gov.me
class MultiSourceRegistry implements ReceiptSource {
  MultiSourceRegistry()
      : _taxCore = TaxCoreClient(),
        _mne = MneClient();

  final TaxCoreClient _taxCore;
  final MneClient _mne;

  ReceiptSource _for(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.contains('mapr.tax.gov.me')) return _mne;
    return _taxCore;
  }

  @override
  Future<RawPortalResponse> fetch(String url) => _for(url).fetch(url);

  @override
  ParsedReceipt parse(RawPortalResponse raw) =>
      _for(raw.verificationUrl).parse(raw);
}
