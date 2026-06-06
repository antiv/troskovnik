/// Apstrakcija nad izvorom podataka računa (TaxCore portal).
///
/// Parser i mrežni klijent stoje IZA ovog interfejsa (sekcija 3) da bi se
/// lako menjali i testirali nad fixture-ima. UI i state machine zavise samo
/// od ovog interfejsa, ne od `dio`/HTML detalja.
library;

import '../../../core/db/enums.dart';

/// Sirovi odgovor portala — ono što je preuzeto sa mreže, pre parsiranja.
///
/// Čuvamo i sirov sadržaj da bismo mogli da re-parsiramo bez novog mrežnog
/// poziva i da hvatamo fixture-e.
class RawPortalResponse {
  const RawPortalResponse({
    required this.verificationUrl,
    required this.statusCode,
    required this.body,
    this.specificationsBody,
    this.contentType,
  });

  final String verificationUrl;
  final int statusCode;

  /// HTML/telo verifikacione stranice.
  final String body;

  /// Telo odgovora za izdvojene stavke (specifications), ako je posebno dohvaćeno.
  final String? specificationsBody;

  final String? contentType;
}

/// Parsiran rezultat — zaglavlje + (eventualne) stavke + stanje.
class ParsedReceipt {
  const ParsedReceipt({
    required this.fetchStatus,
    required this.itemsStatus,
    required this.itemsSource,
    this.header,
    this.items = const [],
    this.journalText,
  });

  final FetchStatus fetchStatus;
  final ItemsStatus itemsStatus;
  final ItemsSource itemsSource;

  final ReceiptHeader? header;
  final List<ParsedLineItem> items;
  final String? journalText;
}

/// Parsirano zaglavlje računa.
class ReceiptHeader {
  const ReceiptHeader({
    required this.merchantName,
    required this.merchantTin,
    this.buyerId,
    this.locationName,
    this.address,
    this.invoiceNumber,
    this.pfrNumber,
    this.pfrTime,
    this.sdcTime,
    this.invoiceCounter,
    this.invoiceType = InvoiceType.normal,
    this.transactionType = TransactionType.sale,
    this.totalAmount = 0,
    this.paymentMethod,
    this.paymentsJson,
    this.taxJson,
  });

  final String merchantName;
  final String merchantTin;

  /// PIB/ID kupca sa fiskalnog računa ("ИД купца"), sirovo `tip:broj`
  /// (npr. "10:104318304", gde "10" = PIB firme). Null kad nije upisan.
  final String? buyerId;

  final String? locationName;
  final String? address;

  final String? invoiceNumber;
  final String? pfrNumber;
  final DateTime? pfrTime;
  final DateTime? sdcTime;
  final String? invoiceCounter;
  final InvoiceType invoiceType;
  final TransactionType transactionType;

  /// Ukupan iznos u para (1/100 RSD).
  final int totalAmount;

  /// Prvi/primarni način plaćanja (naziv). Zadržan radi kompatibilnosti.
  final String? paymentMethod;

  /// Svi načini plaćanja sa iznosima (kombinovano plaćanje), JSON mapa
  /// naziv→iznos_u_para. Null kad nije parsirano.
  final String? paymentsJson;

  final String? taxJson;
}

/// Parsirana stavka.
class ParsedLineItem {
  const ParsedLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.source,
    this.unit,
    this.taxLabel,
    this.taxRate,
    this.isUnparsed = false,
  });

  /// Stavka koja nije mogla da se isparsira — zadržava se sirov tekst u `name`.
  factory ParsedLineItem.unparsed(String rawLine, ItemsSource source) =>
      ParsedLineItem(
        name: rawLine,
        quantity: 0,
        unitPrice: 0,
        total: 0,
        source: source,
        isUnparsed: true,
      );

  final String name;
  final double quantity;
  final String? unit;

  /// U para.
  final int unitPrice;
  final int total;

  final String? taxLabel;
  final double? taxRate;
  final ItemsSource source;
  final bool isUnparsed;
}

/// Greške mrežnog sloja koje state machine mapira u stanja (sekcija 8).
sealed class ReceiptSourceException implements Exception {
  const ReceiptSourceException(this.message);
  final String message;
}

class NoNetworkException extends ReceiptSourceException {
  const NoNetworkException() : super('No network');
}

class PortalUnavailableException extends ReceiptSourceException {
  const PortalUnavailableException(super.message);
}

/// Interfejs koji UI/state machine koriste.
abstract interface class ReceiptSource {
  /// Preuzmi sirov odgovor portala za dati verifikacioni URL.
  Future<RawPortalResponse> fetch(String verificationUrl);

  /// Parsiraj sirov odgovor u strukturiran rezultat (bez mreže).
  ParsedReceipt parse(RawPortalResponse raw);
}
