// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Expense Tracker';

  @override
  String get navScan => 'Scan';

  @override
  String get navReceipts => 'Receipts';

  @override
  String get scanTitle => 'Scan receipt';

  @override
  String get scanHint => 'Point the camera at the fiscal receipt QR code';

  @override
  String get scanManualEntry => 'Manual entry';

  @override
  String get scanBatchMode => 'Scan several in a row';

  @override
  String get scanNotFiscal => 'This is not a fiscal receipt';

  @override
  String get scanPermissionDenied =>
      'Camera access denied. Enable it in settings.';

  @override
  String get resultTitle => 'Scan result';

  @override
  String get resultSave => 'Save';

  @override
  String get resultOpen => 'Open';

  @override
  String resultItemsCount(int count) {
    return '$count items';
  }

  @override
  String get resultItemsPending => 'Items being processed';

  @override
  String get resultDuplicateOpened =>
      'Receipt already saved — opening the existing one.';

  @override
  String get receiptsTitle => 'Receipts';

  @override
  String get receiptsEmpty => 'No saved receipts yet.';

  @override
  String get receiptsSearchHint => 'Search by merchant or item';

  @override
  String get receiptsSortDate => 'Date';

  @override
  String get receiptsSortMerchant => 'Merchant';

  @override
  String get receiptsSortAmount => 'Amount';

  @override
  String get badgeItemsPending => 'Items pending';

  @override
  String get badgeFromJournal => 'From journal';

  @override
  String get badgeInvalid => 'Invalid';

  @override
  String get detailTitle => 'Receipt detail';

  @override
  String get detailHeader => 'Header';

  @override
  String get detailTaxBreakdown => 'Tax breakdown';

  @override
  String get detailItems => 'Items';

  @override
  String get detailNote => 'Note';

  @override
  String get detailMarkBusiness => 'Business receipt';

  @override
  String get detailRefreshNow => 'Refresh now';

  @override
  String get detailAttachPhoto => 'Attach photo';

  @override
  String get detailPendingExplain =>
      'The receipt is saved. The merchant has not posted it to the Tax Administration yet; items will be filled in automatically.';

  @override
  String get detailItemsRefreshed => 'Receipt items have been filled in.';

  @override
  String get detailUnparsedRow => 'Unparsed row';

  @override
  String get manualTitle => 'Manual receipt entry';

  @override
  String get manualTotalAmount => 'Total amount';

  @override
  String get manualPfrNumber => 'PFR number';

  @override
  String get manualPfrTime => 'PFR time';

  @override
  String get manualInvoiceCounter => 'Invoice counter';

  @override
  String get manualSubmit => 'Fetch receipt';

  @override
  String get errNoNetwork =>
      'No network. The receipt is saved and will be completed automatically.';

  @override
  String get errPortalUnavailable =>
      'The Tax Administration portal is currently unavailable. I will retry.';

  @override
  String get errInvalidReceipt =>
      'The receipt does not exist or was cancelled.';

  @override
  String get errGeneric => 'An error occurred.';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get merchantUnknown => 'Unknown merchant';
}
