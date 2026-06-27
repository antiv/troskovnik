import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('sr'),
    Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Cyrl'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In sr, this message translates to:
  /// **'Troškovnik'**
  String get appTitle;

  /// No description provided for @navScan.
  ///
  /// In sr, this message translates to:
  /// **'Skener'**
  String get navScan;

  /// No description provided for @navReceipts.
  ///
  /// In sr, this message translates to:
  /// **'Računi'**
  String get navReceipts;

  /// No description provided for @scanTitle.
  ///
  /// In sr, this message translates to:
  /// **'Skeniraj račun'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In sr, this message translates to:
  /// **'Usmeri kameru na QR kod fiskalnog računa'**
  String get scanHint;

  /// No description provided for @scanManualEntry.
  ///
  /// In sr, this message translates to:
  /// **'Unesi URL'**
  String get scanManualEntry;

  /// No description provided for @scanFromGallery.
  ///
  /// In sr, this message translates to:
  /// **'Iz galerije'**
  String get scanFromGallery;

  /// No description provided for @scanNoQrInImage.
  ///
  /// In sr, this message translates to:
  /// **'Na slici nema čitljivog QR koda'**
  String get scanNoQrInImage;

  /// No description provided for @scanImageFailed.
  ///
  /// In sr, this message translates to:
  /// **'Nije moguće analizirati sliku. Pokušaj ponovo ili skeniraj kamerom.'**
  String get scanImageFailed;

  /// No description provided for @scanBatchMode.
  ///
  /// In sr, this message translates to:
  /// **'Skeniraj više zaredom'**
  String get scanBatchMode;

  /// No description provided for @scanNotFiscal.
  ///
  /// In sr, this message translates to:
  /// **'Ovo nije fiskalni račun'**
  String get scanNotFiscal;

  /// No description provided for @scanPermissionDenied.
  ///
  /// In sr, this message translates to:
  /// **'Pristup kameri je odbijen. Omogući ga u podešavanjima.'**
  String get scanPermissionDenied;

  /// No description provided for @resultTitle.
  ///
  /// In sr, this message translates to:
  /// **'Rezultat skeniranja'**
  String get resultTitle;

  /// No description provided for @resultSave.
  ///
  /// In sr, this message translates to:
  /// **'Sačuvaj'**
  String get resultSave;

  /// No description provided for @resultOpen.
  ///
  /// In sr, this message translates to:
  /// **'Otvori'**
  String get resultOpen;

  /// No description provided for @resultItemsCount.
  ///
  /// In sr, this message translates to:
  /// **'{count} stavki'**
  String resultItemsCount(int count);

  /// No description provided for @resultItemsPending.
  ///
  /// In sr, this message translates to:
  /// **'Stavke u obradi'**
  String get resultItemsPending;

  /// No description provided for @resultDuplicateOpened.
  ///
  /// In sr, this message translates to:
  /// **'Račun je već sačuvan — otvaram postojeći.'**
  String get resultDuplicateOpened;

  /// No description provided for @receiptsTitle.
  ///
  /// In sr, this message translates to:
  /// **'Računi'**
  String get receiptsTitle;

  /// No description provided for @receiptsEmpty.
  ///
  /// In sr, this message translates to:
  /// **'Još nema sačuvanih računa.'**
  String get receiptsEmpty;

  /// No description provided for @receiptsSearchHint.
  ///
  /// In sr, this message translates to:
  /// **'Pretraži po prodavcu ili artiklu'**
  String get receiptsSearchHint;

  /// No description provided for @receiptsSortDate.
  ///
  /// In sr, this message translates to:
  /// **'Datum'**
  String get receiptsSortDate;

  /// No description provided for @receiptsSortMerchant.
  ///
  /// In sr, this message translates to:
  /// **'Prodavac'**
  String get receiptsSortMerchant;

  /// No description provided for @receiptsSortAmount.
  ///
  /// In sr, this message translates to:
  /// **'Iznos'**
  String get receiptsSortAmount;

  /// No description provided for @badgeItemsPending.
  ///
  /// In sr, this message translates to:
  /// **'Stavke u obradi'**
  String get badgeItemsPending;

  /// No description provided for @badgeFromJournal.
  ///
  /// In sr, this message translates to:
  /// **'Iz žurnala'**
  String get badgeFromJournal;

  /// No description provided for @badgeInvalid.
  ///
  /// In sr, this message translates to:
  /// **'Nevažeći'**
  String get badgeInvalid;

  /// No description provided for @detailTitle.
  ///
  /// In sr, this message translates to:
  /// **'Detalj računa'**
  String get detailTitle;

  /// No description provided for @detailHeader.
  ///
  /// In sr, this message translates to:
  /// **'Zaglavlje'**
  String get detailHeader;

  /// No description provided for @detailTaxBreakdown.
  ///
  /// In sr, this message translates to:
  /// **'Obračun poreza'**
  String get detailTaxBreakdown;

  /// No description provided for @detailPaymentMethod.
  ///
  /// In sr, this message translates to:
  /// **'Način plaćanja'**
  String get detailPaymentMethod;

  /// No description provided for @detailItems.
  ///
  /// In sr, this message translates to:
  /// **'Stavke'**
  String get detailItems;

  /// No description provided for @detailNote.
  ///
  /// In sr, this message translates to:
  /// **'Beleška'**
  String get detailNote;

  /// No description provided for @detailMarkBusiness.
  ///
  /// In sr, this message translates to:
  /// **'Poslovni račun'**
  String get detailMarkBusiness;

  /// No description provided for @detailBuyerId.
  ///
  /// In sr, this message translates to:
  /// **'ID kupca'**
  String get detailBuyerId;

  /// No description provided for @detailRefreshNow.
  ///
  /// In sr, this message translates to:
  /// **'Osveži sada'**
  String get detailRefreshNow;

  /// No description provided for @detailAttachPhoto.
  ///
  /// In sr, this message translates to:
  /// **'Priloži fotografiju'**
  String get detailAttachPhoto;

  /// No description provided for @detailPendingExplain.
  ///
  /// In sr, this message translates to:
  /// **'Račun je sačuvan. Prodavac ga još nije proknjižio kod Poreske; stavke će se automatski dopuniti.'**
  String get detailPendingExplain;

  /// No description provided for @detailItemsRefreshed.
  ///
  /// In sr, this message translates to:
  /// **'Stavke računa su dopunjene.'**
  String get detailItemsRefreshed;

  /// No description provided for @detailRefreshTooltip.
  ///
  /// In sr, this message translates to:
  /// **'Osveži sa Poreske uprave'**
  String get detailRefreshTooltip;

  /// No description provided for @detailRefreshConfirmBody.
  ///
  /// In sr, this message translates to:
  /// **'Ponovo preuzeti račun sa Poreske uprave? Postojeće kategorije i garancije se zadržavaju.'**
  String get detailRefreshConfirmBody;

  /// No description provided for @detailUnparsedRow.
  ///
  /// In sr, this message translates to:
  /// **'Neparsiran red'**
  String get detailUnparsedRow;

  /// No description provided for @manualTitle.
  ///
  /// In sr, this message translates to:
  /// **'Ručni unos računa'**
  String get manualTitle;

  /// No description provided for @manualTotalAmount.
  ///
  /// In sr, this message translates to:
  /// **'Ukupan iznos'**
  String get manualTotalAmount;

  /// No description provided for @manualPfrNumber.
  ///
  /// In sr, this message translates to:
  /// **'PFR broj'**
  String get manualPfrNumber;

  /// No description provided for @manualPfrTime.
  ///
  /// In sr, this message translates to:
  /// **'PFR vreme'**
  String get manualPfrTime;

  /// No description provided for @manualInvoiceCounter.
  ///
  /// In sr, this message translates to:
  /// **'Brojač računa'**
  String get manualInvoiceCounter;

  /// No description provided for @manualSubmit.
  ///
  /// In sr, this message translates to:
  /// **'Preuzmi račun'**
  String get manualSubmit;

  /// No description provided for @errNoNetwork.
  ///
  /// In sr, this message translates to:
  /// **'Nema mreže. Račun je sačuvan i biće dopunjen automatski.'**
  String get errNoNetwork;

  /// No description provided for @errPortalUnavailable.
  ///
  /// In sr, this message translates to:
  /// **'Portal Poreske uprave je trenutno nedostupan. Pokušaću ponovo.'**
  String get errPortalUnavailable;

  /// No description provided for @errInvalidReceipt.
  ///
  /// In sr, this message translates to:
  /// **'Račun ne postoji ili je otkazan.'**
  String get errInvalidReceipt;

  /// No description provided for @errGeneric.
  ///
  /// In sr, this message translates to:
  /// **'Došlo je do greške.'**
  String get errGeneric;

  /// No description provided for @retry.
  ///
  /// In sr, this message translates to:
  /// **'Pokušaj ponovo'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In sr, this message translates to:
  /// **'Otkaži'**
  String get cancel;

  /// No description provided for @merchantUnknown.
  ///
  /// In sr, this message translates to:
  /// **'Nepoznat prodavac'**
  String get merchantUnknown;

  /// No description provided for @navWarranties.
  ///
  /// In sr, this message translates to:
  /// **'Garancije'**
  String get navWarranties;

  /// No description provided for @warrantiesTitle.
  ///
  /// In sr, this message translates to:
  /// **'Garancije'**
  String get warrantiesTitle;

  /// No description provided for @warrantiesEmpty.
  ///
  /// In sr, this message translates to:
  /// **'Još nema praćenih garancija. Dodaj garanciju sa računa.'**
  String get warrantiesEmpty;

  /// No description provided for @warrantiesSearchHint.
  ///
  /// In sr, this message translates to:
  /// **'Pretraži po nazivu, prodavcu ili artiklu'**
  String get warrantiesSearchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In sr, this message translates to:
  /// **'Nema rezultata.'**
  String get searchNoResults;

  /// No description provided for @warrantyAdd.
  ///
  /// In sr, this message translates to:
  /// **'Dodaj garanciju'**
  String get warrantyAdd;

  /// No description provided for @warrantyAddForReceipt.
  ///
  /// In sr, this message translates to:
  /// **'Garancija za ceo račun'**
  String get warrantyAddForReceipt;

  /// No description provided for @warrantyAddForItem.
  ///
  /// In sr, this message translates to:
  /// **'Garancija za artikal'**
  String get warrantyAddForItem;

  /// No description provided for @warrantyTitle.
  ///
  /// In sr, this message translates to:
  /// **'Naziv'**
  String get warrantyTitle;

  /// No description provided for @warrantyPurchaseDate.
  ///
  /// In sr, this message translates to:
  /// **'Datum kupovine'**
  String get warrantyPurchaseDate;

  /// No description provided for @warrantyDuration.
  ///
  /// In sr, this message translates to:
  /// **'Trajanje (meseci)'**
  String get warrantyDuration;

  /// No description provided for @warrantyNoteLabel.
  ///
  /// In sr, this message translates to:
  /// **'Beleška'**
  String get warrantyNoteLabel;

  /// No description provided for @warrantyAttachProof.
  ///
  /// In sr, this message translates to:
  /// **'Priloži fotografiju računa'**
  String get warrantyAttachProof;

  /// No description provided for @warrantyPickFromGallery.
  ///
  /// In sr, this message translates to:
  /// **'Iz galerije'**
  String get warrantyPickFromGallery;

  /// No description provided for @warrantyProofAttached.
  ///
  /// In sr, this message translates to:
  /// **'Fotografija priložena'**
  String get warrantyProofAttached;

  /// No description provided for @warrantySave.
  ///
  /// In sr, this message translates to:
  /// **'Sačuvaj garanciju'**
  String get warrantySave;

  /// No description provided for @warrantyOpenReceipt.
  ///
  /// In sr, this message translates to:
  /// **'Prikaži račun'**
  String get warrantyOpenReceipt;

  /// No description provided for @warrantyDelete.
  ///
  /// In sr, this message translates to:
  /// **'Obriši garanciju'**
  String get warrantyDelete;

  /// No description provided for @warrantyDeleteConfirm.
  ///
  /// In sr, this message translates to:
  /// **'Obrisati ovu garanciju i njene podsetnike?'**
  String get warrantyDeleteConfirm;

  /// No description provided for @warrantyExpiresOn.
  ///
  /// In sr, this message translates to:
  /// **'Ističe {date}'**
  String warrantyExpiresOn(String date);

  /// No description provided for @warrantyDaysLeft.
  ///
  /// In sr, this message translates to:
  /// **'Još {days} dana'**
  String warrantyDaysLeft(int days);

  /// No description provided for @warrantyStatusActive.
  ///
  /// In sr, this message translates to:
  /// **'Važi'**
  String get warrantyStatusActive;

  /// No description provided for @warrantyStatusExpiringSoon.
  ///
  /// In sr, this message translates to:
  /// **'Ističe uskoro'**
  String get warrantyStatusExpiringSoon;

  /// No description provided for @warrantyStatusExpired.
  ///
  /// In sr, this message translates to:
  /// **'Isteklo'**
  String get warrantyStatusExpired;

  /// No description provided for @warrantyReminderInfo.
  ///
  /// In sr, this message translates to:
  /// **'Podsetiću te 30 i 7 dana pre isteka.'**
  String get warrantyReminderInfo;

  /// No description provided for @warrantyProofHint.
  ///
  /// In sr, this message translates to:
  /// **'Račun se čuva kao dokaz (papir izbledi).'**
  String get warrantyProofHint;

  /// No description provided for @navAnalytics.
  ///
  /// In sr, this message translates to:
  /// **'Analitika'**
  String get navAnalytics;

  /// No description provided for @analyticsTitle.
  ///
  /// In sr, this message translates to:
  /// **'Analitika potrošnje'**
  String get analyticsTitle;

  /// No description provided for @exportCsv.
  ///
  /// In sr, this message translates to:
  /// **'Izvoz u CSV'**
  String get exportCsv;

  /// No description provided for @exportCurrentMonth.
  ///
  /// In sr, this message translates to:
  /// **'Tekući mesec'**
  String get exportCurrentMonth;

  /// No description provided for @exportPreviousMonth.
  ///
  /// In sr, this message translates to:
  /// **'Prethodni mesec'**
  String get exportPreviousMonth;

  /// No description provided for @exportCustomPeriod.
  ///
  /// In sr, this message translates to:
  /// **'Proizvoljan period'**
  String get exportCustomPeriod;

  /// No description provided for @exportEmpty.
  ///
  /// In sr, this message translates to:
  /// **'Nema računa za izabrani period.'**
  String get exportEmpty;

  /// No description provided for @exportShareText.
  ///
  /// In sr, this message translates to:
  /// **'Izvoz računa (Troškovnik)'**
  String get exportShareText;

  /// No description provided for @analyticsEmpty.
  ///
  /// In sr, this message translates to:
  /// **'Nema dovoljno podataka. Skeniraj nekoliko računa.'**
  String get analyticsEmpty;

  /// No description provided for @analyticsRange3m.
  ///
  /// In sr, this message translates to:
  /// **'3 meseca'**
  String get analyticsRange3m;

  /// No description provided for @analyticsRange12m.
  ///
  /// In sr, this message translates to:
  /// **'12 meseci'**
  String get analyticsRange12m;

  /// No description provided for @analyticsRangeAll.
  ///
  /// In sr, this message translates to:
  /// **'Sve'**
  String get analyticsRangeAll;

  /// No description provided for @analyticsTotalSpent.
  ///
  /// In sr, this message translates to:
  /// **'Ukupno potrošeno'**
  String get analyticsTotalSpent;

  /// No description provided for @analyticsReceiptCount.
  ///
  /// In sr, this message translates to:
  /// **'{count} računa'**
  String analyticsReceiptCount(int count);

  /// No description provided for @analyticsByMonth.
  ///
  /// In sr, this message translates to:
  /// **'Po mesecu'**
  String get analyticsByMonth;

  /// No description provided for @analyticsByMerchant.
  ///
  /// In sr, this message translates to:
  /// **'Najveći prodavci'**
  String get analyticsByMerchant;

  /// No description provided for @analyticsBusinessSplit.
  ///
  /// In sr, this message translates to:
  /// **'Poslovno / lično'**
  String get analyticsBusinessSplit;

  /// No description provided for @analyticsByPayment.
  ///
  /// In sr, this message translates to:
  /// **'Po načinu plaćanja'**
  String get analyticsByPayment;

  /// No description provided for @analyticsPaymentUnknown.
  ///
  /// In sr, this message translates to:
  /// **'Ostalo / nepoznato'**
  String get analyticsPaymentUnknown;

  /// No description provided for @analyticsBusiness.
  ///
  /// In sr, this message translates to:
  /// **'Poslovno'**
  String get analyticsBusiness;

  /// No description provided for @analyticsPersonal.
  ///
  /// In sr, this message translates to:
  /// **'Lično'**
  String get analyticsPersonal;

  /// No description provided for @analyticsTopItems.
  ///
  /// In sr, this message translates to:
  /// **'Najčešći artikli'**
  String get analyticsTopItems;

  /// No description provided for @analyticsByCategory.
  ///
  /// In sr, this message translates to:
  /// **'Po kategorijama'**
  String get analyticsByCategory;

  /// No description provided for @analyticsEstimatedVat.
  ///
  /// In sr, this message translates to:
  /// **'Procenjen PDV'**
  String get analyticsEstimatedVat;

  /// No description provided for @analyticsVatHint.
  ///
  /// In sr, this message translates to:
  /// **'Procena iz stavki sa poreskom stopom; ne uključuje račune bez izdvojenih stavki.'**
  String get analyticsVatHint;

  /// No description provided for @analyticsItemsHint.
  ///
  /// In sr, this message translates to:
  /// **'Bez kategorija — po nazivu artikla. Proširićemo kasnije.'**
  String get analyticsItemsHint;

  /// No description provided for @analyticsAverage.
  ///
  /// In sr, this message translates to:
  /// **'Prosečan račun'**
  String get analyticsAverage;

  /// No description provided for @analyticsPriceHistory.
  ///
  /// In sr, this message translates to:
  /// **'Istorija cene'**
  String get analyticsPriceHistory;

  /// No description provided for @analyticsWhereBought.
  ///
  /// In sr, this message translates to:
  /// **'Gde kupuješ'**
  String get analyticsWhereBought;

  /// No description provided for @analyticsQuantity.
  ///
  /// In sr, this message translates to:
  /// **'Ukupna količina'**
  String get analyticsQuantity;

  /// No description provided for @analyticsPurchaseCount.
  ///
  /// In sr, this message translates to:
  /// **'{count} kupovina'**
  String analyticsPurchaseCount(int count);

  /// No description provided for @settingsTitle.
  ///
  /// In sr, this message translates to:
  /// **'Podešavanja'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In sr, this message translates to:
  /// **'Jezik'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In sr, this message translates to:
  /// **'Sistemski'**
  String get languageSystem;

  /// No description provided for @languageSerbianCyrillic.
  ///
  /// In sr, this message translates to:
  /// **'Srpski (ćirilica)'**
  String get languageSerbianCyrillic;

  /// No description provided for @languageSerbianLatin.
  ///
  /// In sr, this message translates to:
  /// **'Srpski (latinica)'**
  String get languageSerbianLatin;

  /// No description provided for @languageEnglish.
  ///
  /// In sr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @aboutTitle.
  ///
  /// In sr, this message translates to:
  /// **'O aplikaciji'**
  String get aboutTitle;

  /// No description provided for @aboutVersionLabel.
  ///
  /// In sr, this message translates to:
  /// **'VERZIJA'**
  String get aboutVersionLabel;

  /// No description provided for @aboutPoweredBy.
  ///
  /// In sr, this message translates to:
  /// **'POWERED BY'**
  String get aboutPoweredBy;

  /// No description provided for @aboutClose.
  ///
  /// In sr, this message translates to:
  /// **'Zatvori'**
  String get aboutClose;

  /// No description provided for @detailProof.
  ///
  /// In sr, this message translates to:
  /// **'Dokaz'**
  String get detailProof;

  /// No description provided for @detailProofHint.
  ///
  /// In sr, this message translates to:
  /// **'Račun je sačuvan kao dokaz (žurnal + zvanični link Poreske).'**
  String get detailProofHint;

  /// No description provided for @detailOpenOnSuf.
  ///
  /// In sr, this message translates to:
  /// **'Otvori na suf.purs.gov.rs'**
  String get detailOpenOnSuf;

  /// No description provided for @detailDeleteReceipt.
  ///
  /// In sr, this message translates to:
  /// **'Obriši račun'**
  String get detailDeleteReceipt;

  /// No description provided for @detailDeleteReceiptConfirm.
  ///
  /// In sr, this message translates to:
  /// **'Obrisati ovaj račun, njegove stavke i garancije?'**
  String get detailDeleteReceiptConfirm;

  /// No description provided for @receiptFilterAll.
  ///
  /// In sr, this message translates to:
  /// **'Svi'**
  String get receiptFilterAll;

  /// No description provided for @receiptFilterBusiness.
  ///
  /// In sr, this message translates to:
  /// **'Poslovni'**
  String get receiptFilterBusiness;

  /// No description provided for @receiptFilterPersonal.
  ///
  /// In sr, this message translates to:
  /// **'Privatni'**
  String get receiptFilterPersonal;

  /// No description provided for @categoriesTitle.
  ///
  /// In sr, this message translates to:
  /// **'Kategorije'**
  String get categoriesTitle;

  /// No description provided for @categoriesEmpty.
  ///
  /// In sr, this message translates to:
  /// **'Još nema kategorija.'**
  String get categoriesEmpty;

  /// No description provided for @categoriesAdd.
  ///
  /// In sr, this message translates to:
  /// **'Dodaj kategoriju'**
  String get categoriesAdd;

  /// No description provided for @categoriesEdit.
  ///
  /// In sr, this message translates to:
  /// **'Izmeni kategoriju'**
  String get categoriesEdit;

  /// No description provided for @categoriesDelete.
  ///
  /// In sr, this message translates to:
  /// **'Obriši'**
  String get categoriesDelete;

  /// No description provided for @categoriesDeleteConfirm.
  ///
  /// In sr, this message translates to:
  /// **'Obrisati ovu kategoriju? Stavke će ostati bez kategorije.'**
  String get categoriesDeleteConfirm;

  /// No description provided for @categoryNone.
  ///
  /// In sr, this message translates to:
  /// **'Bez kategorije'**
  String get categoryNone;

  /// No description provided for @categoryAssignAll.
  ///
  /// In sr, this message translates to:
  /// **'Označi sve'**
  String get categoryAssignAll;

  /// No description provided for @categoryAssign.
  ///
  /// In sr, this message translates to:
  /// **'Kategorija'**
  String get categoryAssign;

  /// No description provided for @ok.
  ///
  /// In sr, this message translates to:
  /// **'U redu'**
  String get ok;

  /// No description provided for @imageShare.
  ///
  /// In sr, this message translates to:
  /// **'Podeli'**
  String get imageShare;

  /// No description provided for @imageMissing.
  ///
  /// In sr, this message translates to:
  /// **'Slika nije pronađena.'**
  String get imageMissing;

  /// No description provided for @scanAddExpense.
  ///
  /// In sr, this message translates to:
  /// **'Unesi račun'**
  String get scanAddExpense;

  /// No description provided for @expenseTitle.
  ///
  /// In sr, this message translates to:
  /// **'Novi trošak'**
  String get expenseTitle;

  /// No description provided for @expenseMerchantName.
  ///
  /// In sr, this message translates to:
  /// **'Prodavac / opis'**
  String get expenseMerchantName;

  /// No description provided for @expenseMerchantHint.
  ///
  /// In sr, this message translates to:
  /// **'npr. EPS, Infostan, pijaca'**
  String get expenseMerchantHint;

  /// No description provided for @expenseMerchantRequired.
  ///
  /// In sr, this message translates to:
  /// **'Unesite naziv prodavca'**
  String get expenseMerchantRequired;

  /// No description provided for @expenseAmount.
  ///
  /// In sr, this message translates to:
  /// **'Iznos (RSD)'**
  String get expenseAmount;

  /// No description provided for @expenseAmountRequired.
  ///
  /// In sr, this message translates to:
  /// **'Unesite iznos'**
  String get expenseAmountRequired;

  /// No description provided for @expenseAmountInvalid.
  ///
  /// In sr, this message translates to:
  /// **'Iznos mora biti veći od 0'**
  String get expenseAmountInvalid;

  /// No description provided for @expenseDate.
  ///
  /// In sr, this message translates to:
  /// **'Datum'**
  String get expenseDate;

  /// No description provided for @expensePaymentNotSpecified.
  ///
  /// In sr, this message translates to:
  /// **'Nije navedeno'**
  String get expensePaymentNotSpecified;

  /// No description provided for @expensePaymentCash.
  ///
  /// In sr, this message translates to:
  /// **'Gotovina'**
  String get expensePaymentCash;

  /// No description provided for @expensePaymentCard.
  ///
  /// In sr, this message translates to:
  /// **'Kartica'**
  String get expensePaymentCard;

  /// No description provided for @expensePaymentTransfer.
  ///
  /// In sr, this message translates to:
  /// **'Prenos'**
  String get expensePaymentTransfer;

  /// No description provided for @expenseAddItem.
  ///
  /// In sr, this message translates to:
  /// **'Dodaj stavku'**
  String get expenseAddItem;

  /// No description provided for @expenseItemName.
  ///
  /// In sr, this message translates to:
  /// **'Naziv stavke'**
  String get expenseItemName;

  /// No description provided for @expenseSave.
  ///
  /// In sr, this message translates to:
  /// **'Sačuvaj trošak'**
  String get expenseSave;

  /// No description provided for @expenseSaved.
  ///
  /// In sr, this message translates to:
  /// **'Trošak je sačuvan'**
  String get expenseSaved;

  /// No description provided for @expenseTotalRequired.
  ///
  /// In sr, this message translates to:
  /// **'Dodajte barem jednu stavku sa iznosom većim od 0'**
  String get expenseTotalRequired;

  /// No description provided for @backupMenuLabel.
  ///
  /// In sr, this message translates to:
  /// **'Backup i uvoz'**
  String get backupMenuLabel;

  /// No description provided for @backupTitle.
  ///
  /// In sr, this message translates to:
  /// **'Backup i uvoz'**
  String get backupTitle;

  /// No description provided for @backupExplain.
  ///
  /// In sr, this message translates to:
  /// **'Backup pravi ZIP arhivu sa svim računima i slikama. Uvoz ZAMENJUJE sve postojeće podatke.'**
  String get backupExplain;

  /// No description provided for @backupCreate.
  ///
  /// In sr, this message translates to:
  /// **'Napravi backup'**
  String get backupCreate;

  /// No description provided for @backupImport.
  ///
  /// In sr, this message translates to:
  /// **'Uvezi backup'**
  String get backupImport;

  /// No description provided for @backupImportConfirmTitle.
  ///
  /// In sr, this message translates to:
  /// **'Zameniti sve podatke?'**
  String get backupImportConfirmTitle;

  /// No description provided for @backupImportConfirmBody.
  ///
  /// In sr, this message translates to:
  /// **'Ovo će zameniti sve postojeće podatke sadržajem backup-a. Ova akcija se ne može poništiti.'**
  String get backupImportConfirmBody;

  /// No description provided for @backupSuccess.
  ///
  /// In sr, this message translates to:
  /// **'Backup je uspešno uvezen.'**
  String get backupSuccess;

  /// No description provided for @backupErrorCorrupt.
  ///
  /// In sr, this message translates to:
  /// **'Fajl je oštećen ili nije ispravan backup.'**
  String get backupErrorCorrupt;

  /// No description provided for @backupError.
  ///
  /// In sr, this message translates to:
  /// **'Došlo je do greške. Pokušajte ponovo.'**
  String get backupError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'sr':
      {
        switch (locale.scriptCode) {
          case 'Cyrl':
            return AppLocalizationsSrCyrl();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sr':
      return AppLocalizationsSr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
