import '../domain/buyer_identity.dart';
import 'gen/app_localizations.dart';

/// Prevod oznake vrste broja kupca; null = bez oznake (nepoznat format).
String? buyerIdLabelText(AppLocalizations l10n, BuyerIdLabel label) =>
    switch (label) {
      BuyerIdLabel.pib => l10n.buyerIdPib,
      BuyerIdLabel.jib => l10n.buyerIdJib,
      BuyerIdLabel.tin => l10n.buyerIdTin,
      BuyerIdLabel.jmbg => l10n.buyerIdJmbg,
      BuyerIdLabel.jmb => l10n.buyerIdJmb,
      BuyerIdLabel.document => l10n.buyerIdDocument,
      BuyerIdLabel.none => null,
    };
