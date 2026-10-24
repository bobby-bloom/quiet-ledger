import 'package:meta/meta.dart';
import 'package:personal_finance/features/import/domain/text_normalize.dart';

/// A row offered to the transfer matcher.
@immutable
class TransferCandidate {
  const TransferCandidate({
    required this.index,
    required this.accountKey,
    required this.date,
    required this.amountMinor,
    this.text = '',
    this.accountLabel = '',
  });

  /// Caller's row index.
  final int index;
  final String accountKey;
  final DateTime date;
  final int amountMinor;

  /// Payee + note, used to prefer pairs that mention a transfer.
  final String text;
  final String accountLabel;
}

/// A matched debit/credit pair.
@immutable
class TransferMatch {
  const TransferMatch(this.outIndex, this.inIndex, this.dayDiff, this.score);

  /// Index of the outgoing (negative) row.
  final int outIndex;

  /// Index of the incoming (positive) row.
  final int inIndex;
  final int dayDiff;

  /// Higher = more convincing (text mentions a transfer or the other
  /// account).
  final int score;

  String get key => '$outIndex>$inIndex';
}

const _transferWords = [
  'umbuchung',
  'uebertrag',
  'ubertrag',
  'uebertragung',
  'ueberweisung',
  'transfer',
  'sparen',
  'sparplan',
  'sparrate',
  'tagesgeld',
  'eigenuebertrag',
  'kontouebertrag',
  'savings',
  'deposit to',
  'withdrawal from',
];

int _textScore(TransferCandidate a, TransferCandidate b) {
  var s = 0;
  final ta = normaliseText(a.text);
  final tb = normaliseText(b.text);
  for (final w in _transferWords) {
    if (ta.contains(w)) s += 2;
    if (tb.contains(w)) s += 2;
  }
  final la = normaliseText(a.accountLabel);
  final lb = normaliseText(b.accountLabel);
  if (lb.length >= 3 && ta.contains(lb)) s += 3;
  if (la.length >= 3 && tb.contains(la)) s += 3;
  return s;
}

/// Pairs outgoing rows in one account with incoming rows of the same
/// absolute amount in another account at most [windowDays] apart
/// (PLAN.md §2.5 step 8). Each row is used once; closer dates win, then
/// rows whose text mentions a transfer or the other account.
List<TransferMatch> matchTransfers(
  List<TransferCandidate> rows, {
  int windowDays = 3,
}) {
  final incoming = <int, List<TransferCandidate>>{};
  for (final r in rows) {
    if (r.amountMinor > 0) (incoming[r.amountMinor] ??= []).add(r);
  }
  final edges = <TransferMatch>[];
  for (final out in rows) {
    if (out.amountMinor >= 0) continue;
    final bucket = incoming[-out.amountMinor];
    if (bucket == null) continue;
    for (final inc in bucket) {
      if (inc.accountKey == out.accountKey) continue;
      final diff = _days(out.date, inc.date).abs();
      if (diff > windowDays) continue;
      edges.add(
        TransferMatch(out.index, inc.index, diff, _textScore(out, inc)),
      );
    }
  }
  edges.sort((a, b) {
    final d = a.dayDiff.compareTo(b.dayDiff);
    if (d != 0) return d;
    final s = b.score.compareTo(a.score);
    if (s != 0) return s;
    final o = a.outIndex.compareTo(b.outIndex);
    return o != 0 ? o : a.inIndex.compareTo(b.inIndex);
  });
  final used = <int>{};
  final result = <TransferMatch>[];
  for (final e in edges) {
    if (used.contains(e.outIndex) || used.contains(e.inIndex)) continue;
    used
      ..add(e.outIndex)
      ..add(e.inIndex);
    result.add(e);
  }
  result.sort((a, b) => a.outIndex.compareTo(b.outIndex));
  return result;
}

int _days(DateTime a, DateTime b) => DateTime.utc(
  a.year,
  a.month,
  a.day,
).difference(DateTime.utc(b.year, b.month, b.day)).inDays;
