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
  String get scanFromGallery => 'From gallery';

  @override
  String get scanNoQrInImage => 'No readable QR code in the image';

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
  String get detailPaymentMethod => 'Payment method';

  @override
  String get detailItems => 'Items';

  @override
  String get detailNote => 'Note';

  @override
  String get detailMarkBusiness => 'Business receipt';

  @override
  String get detailBuyerId => 'Buyer ID';

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

  @override
  String get navWarranties => 'Warranties';

  @override
  String get warrantiesTitle => 'Warranties';

  @override
  String get warrantiesEmpty =>
      'No tracked warranties yet. Add one from a receipt.';

  @override
  String get warrantyAdd => 'Add warranty';

  @override
  String get warrantyAddForReceipt => 'Warranty for whole receipt';

  @override
  String get warrantyAddForItem => 'Warranty for item';

  @override
  String get warrantyTitle => 'Title';

  @override
  String get warrantyPurchaseDate => 'Purchase date';

  @override
  String get warrantyDuration => 'Duration (months)';

  @override
  String get warrantyNoteLabel => 'Note';

  @override
  String get warrantyAttachProof => 'Attach receipt photo';

  @override
  String get warrantyPickFromGallery => 'From gallery';

  @override
  String get warrantyProofAttached => 'Photo attached';

  @override
  String get warrantySave => 'Save warranty';

  @override
  String get warrantyDelete => 'Delete warranty';

  @override
  String get warrantyDeleteConfirm => 'Delete this warranty and its reminders?';

  @override
  String warrantyExpiresOn(String date) {
    return 'Expires $date';
  }

  @override
  String warrantyDaysLeft(int days) {
    return '$days days left';
  }

  @override
  String get warrantyStatusActive => 'Valid';

  @override
  String get warrantyStatusExpiringSoon => 'Expiring soon';

  @override
  String get warrantyStatusExpired => 'Expired';

  @override
  String get warrantyReminderInfo =>
      'I\'ll remind you 30 and 7 days before it expires.';

  @override
  String get warrantyProofHint => 'The receipt is kept as proof (paper fades).';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get analyticsTitle => 'Spending analytics';

  @override
  String get exportCsv => 'Export to CSV';

  @override
  String get exportCurrentMonth => 'Current month';

  @override
  String get exportPreviousMonth => 'Previous month';

  @override
  String get exportCustomPeriod => 'Custom period';

  @override
  String get exportEmpty => 'No receipts for the selected period.';

  @override
  String get exportShareText => 'Receipts export (Troškovnik)';

  @override
  String get analyticsEmpty => 'Not enough data yet. Scan a few receipts.';

  @override
  String get analyticsRange3m => '3 months';

  @override
  String get analyticsRange12m => '12 months';

  @override
  String get analyticsRangeAll => 'All';

  @override
  String get analyticsTotalSpent => 'Total spent';

  @override
  String analyticsReceiptCount(int count) {
    return '$count receipts';
  }

  @override
  String get analyticsByMonth => 'By month';

  @override
  String get analyticsByMerchant => 'Top merchants';

  @override
  String get analyticsBusinessSplit => 'Business / personal';

  @override
  String get analyticsByPayment => 'By payment method';

  @override
  String get analyticsPaymentUnknown => 'Other / unknown';

  @override
  String get analyticsBusiness => 'Business';

  @override
  String get analyticsPersonal => 'Personal';

  @override
  String get analyticsTopItems => 'Most frequent items';

  @override
  String get analyticsEstimatedVat => 'Estimated VAT';

  @override
  String get analyticsVatHint =>
      'Estimated from items with a tax rate; excludes receipts without itemized lines.';

  @override
  String get analyticsItemsHint =>
      'No categories yet — by item name. To be expanded later.';

  @override
  String get analyticsAverage => 'Average receipt';

  @override
  String get analyticsPriceHistory => 'Price history';

  @override
  String get analyticsWhereBought => 'Where you buy it';

  @override
  String get analyticsQuantity => 'Total quantity';

  @override
  String analyticsPurchaseCount(int count) {
    return '$count purchases';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageSerbianCyrillic => 'Serbian (Cyrillic)';

  @override
  String get languageSerbianLatin => 'Serbian (Latin)';

  @override
  String get languageEnglish => 'English';

  @override
  String get detailProof => 'Proof';

  @override
  String get detailProofHint =>
      'The receipt is kept as proof (journal + official Tax Administration link).';

  @override
  String get detailOpenOnSuf => 'Open on suf.purs.gov.rs';

  @override
  String get detailDeleteReceipt => 'Delete receipt';

  @override
  String get detailDeleteReceiptConfirm =>
      'Delete this receipt, its items and warranties?';

  @override
  String get receiptFilterAll => 'All';

  @override
  String get receiptFilterBusiness => 'Business';

  @override
  String get receiptFilterPersonal => 'Personal';

  @override
  String get imageShare => 'Share';

  @override
  String get imageMissing => 'Image not found.';
}
