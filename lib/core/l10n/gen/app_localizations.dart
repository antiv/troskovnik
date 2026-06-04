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
  /// **'Ručni unos'**
  String get scanManualEntry;

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
