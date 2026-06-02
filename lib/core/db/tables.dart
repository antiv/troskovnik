import 'package:drift/drift.dart';

import 'enums.dart';

/// Prodavci (merchants). Imena polja na engleskom; srpski pojam u komentaru.
@DataClassName('MerchantRow')
class Merchants extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// PIB (tax identification number).
  TextColumn get tin => text()();

  TextColumn get name => text()();

  /// Naziv lokacije / poslovnog prostora.
  TextColumn get locationName => text().nullable()();

  TextColumn get address => text().nullable()();

  DateTimeColumn get firstSeen =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {tin},
      ];
}

/// Računi (receipts).
@DataClassName('ReceiptRow')
class Receipts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get merchantId =>
      integer().references(Merchants, #id)();

  // --- Identifikacija ---
  /// Broj računa.
  TextColumn get invoiceNumber => text().nullable()();

  /// PFR broj.
  TextColumn get pfrNumber => text().nullable()();

  /// PFR vreme.
  DateTimeColumn get pfrTime => dateTime().nullable()();

  /// SDC vreme.
  DateTimeColumn get sdcTime => dateTime().nullable()();

  /// Brojač računa (npr. "12/34ПП").
  TextColumn get invoiceCounter => text().nullable()();

  IntColumn get invoiceType => intEnum<InvoiceType>()
      .withDefault(Constant(InvoiceType.normal.index))();

  IntColumn get transactionType => intEnum<TransactionType>()
      .withDefault(Constant(TransactionType.sale.index))();

  // --- Iznosi ---
  /// Ukupan iznos u para (1/100 RSD).
  IntColumn get totalAmount => integer().withDefault(const Constant(0))();

  /// Oblik plaćanja (gotovina, kartica, ...).
  TextColumn get paymentMethod => text().nullable()();

  /// Obračun poreza po stopama, serijalizovan kao JSON.
  TextColumn get taxJson => text().nullable()();

  // --- Izvor ---
  TextColumn get verificationUrl => text()();
  TextColumn get token => text().nullable()();

  /// Žurnal (tekstualni ispis računa).
  TextColumn get journalText => text().nullable()();

  // --- Stanje ---
  IntColumn get fetchStatus => intEnum<FetchStatus>()
      .withDefault(Constant(FetchStatus.pending.index))();

  IntColumn get itemsStatus => intEnum<ItemsStatus>()
      .withDefault(Constant(ItemsStatus.none.index))();

  IntColumn get itemsSource => intEnum<ItemsSource>()
      .withDefault(Constant(ItemsSource.none.index))();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  // --- Korisničko ---
  BoolColumn get isBusiness =>
      boolean().withDefault(const Constant(false))();

  TextColumn get imagePath => text().nullable()();

  TextColumn get note => text().nullable()();

  // --- Meta ---
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        // Isti račun se ne sme upisati dvaput.
        {invoiceNumber, pfrNumber},
      ];
}

/// Stavke računa (line items).
@DataClassName('LineItemRow')
class LineItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get receiptId =>
      integer().references(Receipts, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  /// Količina (npr. 1.0, 0.532 kg) — čuva se kao realan broj.
  RealColumn get quantity => real().withDefault(const Constant(1.0))();

  /// Jedinica mere (kom, kg, l, ...).
  TextColumn get unit => text().nullable()();

  /// Jedinična cena u para.
  IntColumn get unitPrice => integer().withDefault(const Constant(0))();

  /// Ukupno za stavku u para.
  IntColumn get total => integer().withDefault(const Constant(0))();

  /// Poreska oznaka (Ђ, Е, А, ...).
  TextColumn get taxLabel => text().nullable()();

  /// Poreska stopa u procentima (npr. 20.0, 10.0, 0.0).
  RealColumn get taxRate => real().nullable()();

  IntColumn get source => intEnum<ItemsSource>()
      .withDefault(Constant(ItemsSource.none.index))();

  /// Red koji nije mogao da se isparsira — zadržan kao sirovi tekst.
  BoolColumn get isUnparsed =>
      boolean().withDefault(const Constant(false))();

  /// Za kasnije (AI kategorizacija) — NE koristi se sada.
  IntColumn get categoryId => integer().nullable()();
}

/// Garancije / saobraznost (warranties).
///
/// Killer feature: prati rok garancije po stavci ILI po celom računu, podseti
/// pre isteka, i koristi sačuvan račun (journal/URL/foto) kao dokaz.
@DataClassName('WarrantyRow')
class Warranties extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Račun koji služi kao dokaz (uvek postoji).
  IntColumn get receiptId =>
      integer().references(Receipts, #id, onDelete: KeyAction.cascade)();

  /// Konkretna stavka, ako je garancija za jedan artikal (nullable → ceo račun).
  IntColumn get lineItemId =>
      integer().nullable().references(LineItems, #id, onDelete: KeyAction.setNull)();

  /// Naziv (predefinisan iz stavke/prodavca, korisnik može da izmeni).
  TextColumn get title => text()();

  /// Datum kupovine (default = pfr_time računa).
  DateTimeColumn get purchaseDate => dateTime()();

  /// Trajanje u mesecima (default 24 — zakonska saobraznost u Srbiji).
  IntColumn get durationMonths => integer().withDefault(const Constant(24))();

  /// Datum isteka (izračunat i upisan radi lakšeg upita/sortiranja).
  DateTimeColumn get expiryDate => dateTime()();

  TextColumn get note => text().nullable()();

  /// Putanja do priložene fotografije računa kao dokaza (papir izbledi).
  TextColumn get proofImagePath => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
