import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/enums.dart';
import '../../receipts/data/receipt_providers.dart';
import '../../source/domain/receipt_source.dart';
import '../domain/verification_url.dart';

/// Ishod obrade jednog skeniranja.
sealed class ScanOutcome {
  const ScanOutcome();
}

class ScanSaved extends ScanOutcome {
  const ScanSaved({
    required this.receiptId,
    required this.wasDuplicate,
    required this.parsed,
  });
  final int receiptId;
  final bool wasDuplicate;
  final ParsedReceipt parsed;
}

class ScanNotFiscal extends ScanOutcome {
  const ScanNotFiscal(this.reason);
  final InvalidReason reason;
}

class ScanError extends ScanOutcome {
  const ScanError(this.kind);
  final ScanErrorKind kind;
}

enum ScanErrorKind { noNetwork, portalUnavailable, invalidReceipt, generic }

/// Obrada skeniranog sadržaja: validacija → fetch → parse → save.
/// Vraća [ScanOutcome] da UI prikaže odgovarajuće stanje.
class ScanController {
  ScanController(this._ref, {VerificationUrlValidator? validator})
      : _validator = validator ?? const VerificationUrlValidator();

  final Ref _ref;
  final VerificationUrlValidator _validator;

  Future<ScanOutcome> process(String rawScan) async {
    final validation = _validator.validate(rawScan);
    if (validation is InvalidVerificationUrl) {
      return ScanNotFiscal(validation.reason);
    }
    final valid = validation as ValidVerificationUrl;

    final source = _ref.read(receiptSourceProvider);
    final repo = await _ref.read(receiptRepositoryProvider.future);

    try {
      final raw = await source.fetch(valid.normalizedUrl);
      final parsed = source.parse(raw);

      if (parsed.fetchStatus == FetchStatus.invalid) {
        return const ScanError(ScanErrorKind.invalidReceipt);
      }

      final result = await repo.saveParsed(
        verificationUrl: valid.normalizedUrl,
        token: valid.token,
        parsed: parsed,
      );
      return ScanSaved(
        receiptId: result.receiptId,
        wasDuplicate: result.wasDuplicate,
        parsed: parsed,
      );
    } on NoNetworkException {
      // Sačuvaj zapis i bez podataka da se ne izgubi (sekcija 8).
      final result = await repo.saveParsed(
        verificationUrl: valid.normalizedUrl,
        token: valid.token,
        parsed: const ParsedReceipt(
          fetchStatus: FetchStatus.pending,
          itemsStatus: ItemsStatus.pendingServer,
          itemsSource: ItemsSource.none,
        ),
      );
      return ScanSaved(
        receiptId: result.receiptId,
        wasDuplicate: result.wasDuplicate,
        parsed: const ParsedReceipt(
          fetchStatus: FetchStatus.pending,
          itemsStatus: ItemsStatus.pendingServer,
          itemsSource: ItemsSource.none,
        ),
      );
    } on PortalUnavailableException {
      return const ScanError(ScanErrorKind.portalUnavailable);
    } catch (_) {
      return const ScanError(ScanErrorKind.generic);
    }
  }
}

final scanControllerProvider =
    Provider<ScanController>((ref) => ScanController(ref));
