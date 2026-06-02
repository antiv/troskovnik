/// Eksponencijalni backoff za re-fetch stavki koje još nisu na serveru
/// (instrukcije.md, sekcija 5, tačka 2).
///
/// Intervali: +5 min, +30 min, +2 h, +6 h, +24 h; maksimalno [maxRetries]
/// pokušaja (default 6 → poslednji interval se ponovi).
library;

class RetryPolicy {
  const RetryPolicy({this.maxRetries = 6});

  final int maxRetries;

  static const _intervals = <Duration>[
    Duration(minutes: 5),
    Duration(minutes: 30),
    Duration(hours: 2),
    Duration(hours: 6),
    Duration(hours: 24),
  ];

  /// Da li je dozvoljen još jedan pokušaj posle [retryCount] dosadašnjih.
  bool canRetry(int retryCount) => retryCount < maxRetries;

  /// Vreme sledećeg pokušaja računato od [from] (default sada), na osnovu
  /// dosadašnjeg [retryCount]. Vraća null ako su pokušaji iscrpljeni.
  DateTime? nextRetryAt(int retryCount, {DateTime? from}) {
    if (!canRetry(retryCount)) return null;
    final base = from ?? DateTime.now();
    final idx = retryCount < _intervals.length
        ? retryCount
        : _intervals.length - 1;
    return base.add(_intervals[idx]);
  }
}
