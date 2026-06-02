// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Serbian (`sr`).
class AppLocalizationsSr extends AppLocalizations {
  AppLocalizationsSr([String locale = 'sr']) : super(locale);

  @override
  String get appTitle => 'Troškovnik';

  @override
  String get navScan => 'Skener';

  @override
  String get navReceipts => 'Računi';

  @override
  String get scanTitle => 'Skeniraj račun';

  @override
  String get scanHint => 'Usmeri kameru na QR kod fiskalnog računa';

  @override
  String get scanManualEntry => 'Ručni unos';

  @override
  String get scanBatchMode => 'Skeniraj više zaredom';

  @override
  String get scanNotFiscal => 'Ovo nije fiskalni račun';

  @override
  String get scanPermissionDenied =>
      'Pristup kameri je odbijen. Omogući ga u podešavanjima.';

  @override
  String get resultTitle => 'Rezultat skeniranja';

  @override
  String get resultSave => 'Sačuvaj';

  @override
  String get resultOpen => 'Otvori';

  @override
  String resultItemsCount(int count) {
    return '$count stavki';
  }

  @override
  String get resultItemsPending => 'Stavke u obradi';

  @override
  String get resultDuplicateOpened =>
      'Račun je već sačuvan — otvaram postojeći.';

  @override
  String get receiptsTitle => 'Računi';

  @override
  String get receiptsEmpty => 'Još nema sačuvanih računa.';

  @override
  String get receiptsSearchHint => 'Pretraži po prodavcu ili artiklu';

  @override
  String get receiptsSortDate => 'Datum';

  @override
  String get receiptsSortMerchant => 'Prodavac';

  @override
  String get receiptsSortAmount => 'Iznos';

  @override
  String get badgeItemsPending => 'Stavke u obradi';

  @override
  String get badgeFromJournal => 'Iz žurnala';

  @override
  String get badgeInvalid => 'Nevažeći';

  @override
  String get detailTitle => 'Detalj računa';

  @override
  String get detailHeader => 'Zaglavlje';

  @override
  String get detailTaxBreakdown => 'Obračun poreza';

  @override
  String get detailItems => 'Stavke';

  @override
  String get detailNote => 'Beleška';

  @override
  String get detailMarkBusiness => 'Poslovni račun';

  @override
  String get detailRefreshNow => 'Osveži sada';

  @override
  String get detailAttachPhoto => 'Priloži fotografiju';

  @override
  String get detailPendingExplain =>
      'Račun je sačuvan. Prodavac ga još nije proknjižio kod Poreske; stavke će se automatski dopuniti.';

  @override
  String get detailItemsRefreshed => 'Stavke računa su dopunjene.';

  @override
  String get detailUnparsedRow => 'Neparsiran red';

  @override
  String get manualTitle => 'Ručni unos računa';

  @override
  String get manualTotalAmount => 'Ukupan iznos';

  @override
  String get manualPfrNumber => 'PFR broj';

  @override
  String get manualPfrTime => 'PFR vreme';

  @override
  String get manualInvoiceCounter => 'Brojač računa';

  @override
  String get manualSubmit => 'Preuzmi račun';

  @override
  String get errNoNetwork =>
      'Nema mreže. Račun je sačuvan i biće dopunjen automatski.';

  @override
  String get errPortalUnavailable =>
      'Portal Poreske uprave je trenutno nedostupan. Pokušaću ponovo.';

  @override
  String get errInvalidReceipt => 'Račun ne postoji ili je otkazan.';

  @override
  String get errGeneric => 'Došlo je do greške.';

  @override
  String get retry => 'Pokušaj ponovo';

  @override
  String get cancel => 'Otkaži';

  @override
  String get merchantUnknown => 'Nepoznat prodavac';

  @override
  String get navWarranties => 'Garancije';

  @override
  String get warrantiesTitle => 'Garancije';

  @override
  String get warrantiesEmpty =>
      'Još nema praćenih garancija. Dodaj garanciju sa računa.';

  @override
  String get warrantyAdd => 'Dodaj garanciju';

  @override
  String get warrantyAddForReceipt => 'Garancija za ceo račun';

  @override
  String get warrantyAddForItem => 'Garancija za artikal';

  @override
  String get warrantyTitle => 'Naziv';

  @override
  String get warrantyPurchaseDate => 'Datum kupovine';

  @override
  String get warrantyDuration => 'Trajanje (meseci)';

  @override
  String get warrantyNoteLabel => 'Beleška';

  @override
  String get warrantyAttachProof => 'Priloži fotografiju računa';

  @override
  String get warrantyProofAttached => 'Fotografija priložena';

  @override
  String get warrantySave => 'Sačuvaj garanciju';

  @override
  String get warrantyDelete => 'Obriši garanciju';

  @override
  String get warrantyDeleteConfirm =>
      'Obrisati ovu garanciju i njene podsetnike?';

  @override
  String warrantyExpiresOn(String date) {
    return 'Ističe $date';
  }

  @override
  String warrantyDaysLeft(int days) {
    return 'Još $days dana';
  }

  @override
  String get warrantyStatusActive => 'Važi';

  @override
  String get warrantyStatusExpiringSoon => 'Ističe uskoro';

  @override
  String get warrantyStatusExpired => 'Isteklo';

  @override
  String get warrantyReminderInfo => 'Podsetiću te 30 i 7 dana pre isteka.';

  @override
  String get warrantyProofHint => 'Račun se čuva kao dokaz (papir izbledi).';
}
