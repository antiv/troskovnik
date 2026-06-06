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
  String get scanFromGallery => 'Iz galerije';

  @override
  String get scanNoQrInImage => 'Na slici nema čitljivog QR koda';

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
  String get detailPaymentMethod => 'Način plaćanja';

  @override
  String get detailItems => 'Stavke';

  @override
  String get detailNote => 'Beleška';

  @override
  String get detailMarkBusiness => 'Poslovni račun';

  @override
  String get detailBuyerId => 'ID kupca';

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
  String get warrantyPickFromGallery => 'Iz galerije';

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

  @override
  String get navAnalytics => 'Analitika';

  @override
  String get analyticsTitle => 'Analitika potrošnje';

  @override
  String get exportCsv => 'Izvoz u CSV';

  @override
  String get exportCurrentMonth => 'Tekući mesec';

  @override
  String get exportPreviousMonth => 'Prethodni mesec';

  @override
  String get exportCustomPeriod => 'Proizvoljan period';

  @override
  String get exportEmpty => 'Nema računa za izabrani period.';

  @override
  String get exportShareText => 'Izvoz računa (Troškovnik)';

  @override
  String get analyticsEmpty =>
      'Nema dovoljno podataka. Skeniraj nekoliko računa.';

  @override
  String get analyticsRange3m => '3 meseca';

  @override
  String get analyticsRange12m => '12 meseci';

  @override
  String get analyticsRangeAll => 'Sve';

  @override
  String get analyticsTotalSpent => 'Ukupno potrošeno';

  @override
  String analyticsReceiptCount(int count) {
    return '$count računa';
  }

  @override
  String get analyticsByMonth => 'Po mesecu';

  @override
  String get analyticsByMerchant => 'Najveći prodavci';

  @override
  String get analyticsBusinessSplit => 'Poslovno / lično';

  @override
  String get analyticsByPayment => 'Po načinu plaćanja';

  @override
  String get analyticsPaymentUnknown => 'Ostalo / nepoznato';

  @override
  String get analyticsBusiness => 'Poslovno';

  @override
  String get analyticsPersonal => 'Lično';

  @override
  String get analyticsTopItems => 'Najčešći artikli';

  @override
  String get analyticsEstimatedVat => 'Procenjen PDV';

  @override
  String get analyticsVatHint =>
      'Procena iz stavki sa poreskom stopom; ne uključuje račune bez izdvojenih stavki.';

  @override
  String get analyticsItemsHint =>
      'Bez kategorija — po nazivu artikla. Proširićemo kasnije.';

  @override
  String get analyticsAverage => 'Prosečan račun';

  @override
  String get analyticsPriceHistory => 'Istorija cene';

  @override
  String get analyticsWhereBought => 'Gde kupuješ';

  @override
  String get analyticsQuantity => 'Ukupna količina';

  @override
  String analyticsPurchaseCount(int count) {
    return '$count kupovina';
  }

  @override
  String get settingsTitle => 'Podešavanja';

  @override
  String get settingsLanguage => 'Jezik';

  @override
  String get languageSystem => 'Sistemski';

  @override
  String get languageSerbianCyrillic => 'Srpski (ćirilica)';

  @override
  String get languageSerbianLatin => 'Srpski (latinica)';

  @override
  String get languageEnglish => 'English';

  @override
  String get detailProof => 'Dokaz';

  @override
  String get detailProofHint =>
      'Račun je sačuvan kao dokaz (žurnal + zvanični link Poreske).';

  @override
  String get detailOpenOnSuf => 'Otvori na suf.purs.gov.rs';

  @override
  String get detailDeleteReceipt => 'Obriši račun';

  @override
  String get detailDeleteReceiptConfirm =>
      'Obrisati ovaj račun, njegove stavke i garancije?';

  @override
  String get receiptFilterAll => 'Svi';

  @override
  String get receiptFilterBusiness => 'Poslovni';

  @override
  String get receiptFilterPersonal => 'Privatni';

  @override
  String get imageShare => 'Podeli';

  @override
  String get imageMissing => 'Slika nije pronađena.';
}

/// The translations for Serbian, using the Cyrillic script (`sr_Cyrl`).
class AppLocalizationsSrCyrl extends AppLocalizationsSr {
  AppLocalizationsSrCyrl() : super('sr_Cyrl');

  @override
  String get appTitle => 'Трошковник';

  @override
  String get navScan => 'Скенер';

  @override
  String get navReceipts => 'Рачуни';

  @override
  String get scanTitle => 'Скенирај рачун';

  @override
  String get scanHint => 'Усмери камеру на QR код фискалног рачуна';

  @override
  String get scanManualEntry => 'Ручни унос';

  @override
  String get scanFromGallery => 'Из галерије';

  @override
  String get scanNoQrInImage => 'На слици нема читљивог QR кода';

  @override
  String get scanBatchMode => 'Скенирај више заредом';

  @override
  String get scanNotFiscal => 'Ово није фискални рачун';

  @override
  String get scanPermissionDenied =>
      'Приступ камери је одбијен. Омогући га у подешавањима.';

  @override
  String get resultTitle => 'Резултат скенирања';

  @override
  String get resultSave => 'Сачувај';

  @override
  String get resultOpen => 'Отвори';

  @override
  String resultItemsCount(int count) {
    return '$count ставки';
  }

  @override
  String get resultItemsPending => 'Ставке у обради';

  @override
  String get resultDuplicateOpened =>
      'Рачун је већ сачуван — отварам постојећи.';

  @override
  String get receiptsTitle => 'Рачуни';

  @override
  String get receiptsEmpty => 'Још нема сачуваних рачуна.';

  @override
  String get receiptsSearchHint => 'Претражи по продавцу или артиклу';

  @override
  String get receiptsSortDate => 'Датум';

  @override
  String get receiptsSortMerchant => 'Продавац';

  @override
  String get receiptsSortAmount => 'Износ';

  @override
  String get badgeItemsPending => 'Ставке у обради';

  @override
  String get badgeFromJournal => 'Из журнала';

  @override
  String get badgeInvalid => 'Неважећи';

  @override
  String get detailTitle => 'Детаљ рачуна';

  @override
  String get detailHeader => 'Заглавље';

  @override
  String get detailTaxBreakdown => 'Обрачун пореза';

  @override
  String get detailPaymentMethod => 'Начин плаћања';

  @override
  String get detailItems => 'Ставке';

  @override
  String get detailNote => 'Белешка';

  @override
  String get detailMarkBusiness => 'Пословни рачун';

  @override
  String get detailBuyerId => 'ИД купца';

  @override
  String get detailRefreshNow => 'Освежи сада';

  @override
  String get detailAttachPhoto => 'Приложи фотографију';

  @override
  String get detailPendingExplain =>
      'Рачун је сачуван. Продавац га још није прокњижио код Пореске; ставке ће се аутоматски допунити.';

  @override
  String get detailItemsRefreshed => 'Ставке рачуна су допуњене.';

  @override
  String get detailUnparsedRow => 'Непарсиран ред';

  @override
  String get manualTitle => 'Ручни унос рачуна';

  @override
  String get manualTotalAmount => 'Укупан износ';

  @override
  String get manualPfrNumber => 'ПФР број';

  @override
  String get manualPfrTime => 'ПФР време';

  @override
  String get manualInvoiceCounter => 'Бројач рачуна';

  @override
  String get manualSubmit => 'Преузми рачун';

  @override
  String get errNoNetwork =>
      'Нема мреже. Рачун је сачуван и биће допуњен аутоматски.';

  @override
  String get errPortalUnavailable =>
      'Портал Пореске управе је тренутно недоступан. Покушаћу поново.';

  @override
  String get errInvalidReceipt => 'Рачун не постоји или је отказан.';

  @override
  String get errGeneric => 'Дошло је до грешке.';

  @override
  String get retry => 'Покушај поново';

  @override
  String get cancel => 'Откажи';

  @override
  String get merchantUnknown => 'Непознат продавац';

  @override
  String get navWarranties => 'Гаранције';

  @override
  String get warrantiesTitle => 'Гаранције';

  @override
  String get warrantiesEmpty =>
      'Још нема праћених гаранција. Додај гаранцију са рачуна.';

  @override
  String get warrantyAdd => 'Додај гаранцију';

  @override
  String get warrantyAddForReceipt => 'Гаранција за цео рачун';

  @override
  String get warrantyAddForItem => 'Гаранција за артикал';

  @override
  String get warrantyTitle => 'Назив';

  @override
  String get warrantyPurchaseDate => 'Датум куповине';

  @override
  String get warrantyDuration => 'Трајање (месеци)';

  @override
  String get warrantyNoteLabel => 'Белешка';

  @override
  String get warrantyAttachProof => 'Приложи фотографију рачуна';

  @override
  String get warrantyPickFromGallery => 'Из галерије';

  @override
  String get warrantyProofAttached => 'Фотографија приложена';

  @override
  String get warrantySave => 'Сачувај гаранцију';

  @override
  String get warrantyDelete => 'Обриши гаранцију';

  @override
  String get warrantyDeleteConfirm =>
      'Обрисати ову гаранцију и њене подсетнике?';

  @override
  String warrantyExpiresOn(String date) {
    return 'Истиче $date';
  }

  @override
  String warrantyDaysLeft(int days) {
    return 'Још $days дана';
  }

  @override
  String get warrantyStatusActive => 'Важи';

  @override
  String get warrantyStatusExpiringSoon => 'Истиче ускоро';

  @override
  String get warrantyStatusExpired => 'Истекло';

  @override
  String get warrantyReminderInfo => 'Подсетићу те 30 и 7 дана пре истека.';

  @override
  String get warrantyProofHint => 'Рачун се чува као доказ (папир избледи).';

  @override
  String get navAnalytics => 'Аналитика';

  @override
  String get analyticsTitle => 'Аналитика потрошње';

  @override
  String get exportCsv => 'Извоз у CSV';

  @override
  String get exportCurrentMonth => 'Текући месец';

  @override
  String get exportPreviousMonth => 'Претходни месец';

  @override
  String get exportCustomPeriod => 'Произвољан период';

  @override
  String get exportEmpty => 'Нема рачуна за изабрани период.';

  @override
  String get exportShareText => 'Извоз рачуна (Трошковник)';

  @override
  String get analyticsEmpty =>
      'Нема довољно података. Скенирај неколико рачуна.';

  @override
  String get analyticsRange3m => '3 месеца';

  @override
  String get analyticsRange12m => '12 месеци';

  @override
  String get analyticsRangeAll => 'Све';

  @override
  String get analyticsTotalSpent => 'Укупно потрошено';

  @override
  String analyticsReceiptCount(int count) {
    return '$count рачуна';
  }

  @override
  String get analyticsByMonth => 'По месецу';

  @override
  String get analyticsByMerchant => 'Највећи продавци';

  @override
  String get analyticsBusinessSplit => 'Пословно / лично';

  @override
  String get analyticsByPayment => 'По начину плаћања';

  @override
  String get analyticsPaymentUnknown => 'Остало / непознато';

  @override
  String get analyticsBusiness => 'Пословно';

  @override
  String get analyticsPersonal => 'Лично';

  @override
  String get analyticsTopItems => 'Најчешћи артикли';

  @override
  String get analyticsEstimatedVat => 'Процењен ПДВ';

  @override
  String get analyticsVatHint =>
      'Процена из ставки са пореском стопом; не укључује рачуне без издвојених ставки.';

  @override
  String get analyticsItemsHint =>
      'Без категорија — по називу артикла. Проширићемо касније.';

  @override
  String get analyticsAverage => 'Просечан рачун';

  @override
  String get analyticsPriceHistory => 'Историја цене';

  @override
  String get analyticsWhereBought => 'Где купујеш';

  @override
  String get analyticsQuantity => 'Укупна количина';

  @override
  String analyticsPurchaseCount(int count) {
    return '$count куповина';
  }

  @override
  String get settingsTitle => 'Подешавања';

  @override
  String get settingsLanguage => 'Језик';

  @override
  String get languageSystem => 'Системски';

  @override
  String get languageSerbianCyrillic => 'Српски (ћирилица)';

  @override
  String get languageSerbianLatin => 'Српски (латиница)';

  @override
  String get languageEnglish => 'English';

  @override
  String get detailProof => 'Доказ';

  @override
  String get detailProofHint =>
      'Рачун је сачуван као доказ (журнал + званични линк Пореске).';

  @override
  String get detailOpenOnSuf => 'Отвори на suf.purs.gov.rs';

  @override
  String get detailDeleteReceipt => 'Обриши рачун';

  @override
  String get detailDeleteReceiptConfirm =>
      'Обрисати овај рачун, његове ставке и гаранције?';

  @override
  String get receiptFilterAll => 'Сви';

  @override
  String get receiptFilterBusiness => 'Пословни';

  @override
  String get receiptFilterPersonal => 'Приватни';

  @override
  String get imageShare => 'Подели';

  @override
  String get imageMissing => 'Слика није пронађена.';
}
