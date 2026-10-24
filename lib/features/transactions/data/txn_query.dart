import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/money/money_input.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/transactions/domain/txn_filter.dart';

/// A piece of SQL with its bound variables.
@immutable
class SqlPart {
  const SqlPart(this.sql, [this.vars = const []]);

  final String sql;
  final List<Variable<Object>> vars;

  bool get isEmpty => sql.isEmpty;
}

/// One ORDER BY term of a list sort.
typedef SortTerm = ({String expr, bool desc});

/// Position of a row in the list's sort order: the values of the sort terms
/// (raw SQL values) for keyset pagination.
@immutable
class TxnCursor {
  const TxnCursor(this.values);

  final List<Object> values;

  @override
  bool operator ==(Object other) =>
      other is TxnCursor &&
      other.values.length == values.length &&
      Iterable<int>.generate(values.length)
          .every((i) => other.values[i] == values[i]);

  @override
  int get hashCode => Object.hashAll(values);

  @override
  String toString() => 'TxnCursor($values)';
}

/// Builds the SQL for the transaction list. All queries use the aliases
/// `t` (transactions) and `p` (the transfer peer, LEFT JOINed).
abstract final class TxnQuery {
  static const from =
      'FROM transactions t '
      'LEFT JOIN transactions p ON p.id = t.transfer_peer_id';

  /// Sort terms; the last term is always the rowid so the order is total
  /// and keyset pagination is stable.
  static List<SortTerm> sortTerms(TxnSort sort) => switch (sort) {
    TxnSort.dateDesc => const [
      (expr: 't.date', desc: true),
      (expr: 't.rowid', desc: true),
    ],
    TxnSort.dateAsc => const [
      (expr: 't.date', desc: false),
      (expr: 't.rowid', desc: false),
    ],
    TxnSort.amountDesc => const [
      (expr: 'ABS(t.amount_minor)', desc: true),
      (expr: 't.date', desc: true),
      (expr: 't.rowid', desc: true),
    ],
    TxnSort.amountAsc => const [
      (expr: 'ABS(t.amount_minor)', desc: false),
      (expr: 't.date', desc: true),
      (expr: 't.rowid', desc: true),
    ],
    TxnSort.payee => const [
      (expr: "COALESCE(t.payee, '') COLLATE NOCASE", desc: false),
      (expr: 't.date', desc: true),
      (expr: 't.rowid', desc: true),
    ],
  };

  /// `expr AS k0, expr AS k1, ...` for reading cursors back.
  static String sortKeyColumns(TxnSort sort) {
    final terms = sortTerms(sort);
    return [for (var i = 0; i < terms.length; i++) '${terms[i].expr} AS k$i']
        .join(', ');
  }

  static String orderBy(TxnSort sort) =>
      'ORDER BY ${sortTerms(sort).map((t) => '${t.expr} ${t.desc ? 'DESC' : 'ASC'}').join(', ')}';

  /// Rows strictly after [c] in [sort] order.
  static SqlPart after(TxnSort sort, TxnCursor c) {
    final terms = sortTerms(sort);
    final vars = <Variable<Object>>[];
    String build(int i) {
      final t = terms[i];
      final op = t.desc ? '<' : '>';
      vars.add(Variable<Object>(c.values[i]));
      if (i == terms.length - 1) return '${t.expr} $op ?';
      vars.add(Variable<Object>(c.values[i]));
      return '(${t.expr} $op ? OR (${t.expr} = ? AND ${build(i + 1)}))';
    }

    // A redundant coarse bound on the first term lets SQLite use the index.
    final first = terms.first;
    final coarse = '${first.expr} ${first.desc ? '<=' : '>='} ?';
    final lex = build(0);
    return SqlPart('($coarse AND $lex)', [
      Variable<Object>(c.values.first),
      ...vars,
    ]);
  }

  /// Rows at or before [c] in [sort] order (upper bound of a loaded page).
  static SqlPart atOrBefore(TxnSort sort, TxnCursor c) {
    final a = after(sort, c);
    final first = sortTerms(sort).first;
    final coarse = '${first.expr} ${first.desc ? '>=' : '<='} ?';
    return SqlPart('($coarse AND NOT ${a.sql})', [
      Variable<Object>(c.values.first),
      ...a.vars,
    ]);
  }

  /// Converts free text into an FTS5 query: every word becomes a quoted
  /// prefix term (`"cafe"*`), all AND-combined. Returns '' when the text has
  /// no searchable words.
  static String ftsQuery(String search) {
    final words = RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    ).allMatches(search).map((m) => m.group(0)!);
    return words.map((w) => '"$w"*').join(' ');
  }

  static final _amountLike = RegExp(r'^[\s€+\-−]*[0-9][0-9.,\s]*€?\s*$');

  /// If [search] is a plain amount ("24,80", "€12"), its absolute value in
  /// minor units.
  static int? searchAmount(String search) {
    if (!_amountLike.hasMatch(search)) return null;
    return parseAmountInput(search)?.abs();
  }

  /// WHERE conditions for [f] (without the `WHERE` keyword). Always
  /// excludes soft-deleted rows and shows a transfer only once unless the
  /// list is filtered to the accounts of both legs.
  static SqlPart where(TxnFilter f, {required DateTime now}) {
    final parts = <String>['t.deleted_at IS NULL'];
    final vars = <Variable<Object>>[];

    List<String> placeholders(Iterable<Object> values) {
      for (final v in values) {
        vars.add(Variable<Object>(v));
      }
      return List.filled(values.length, '?');
    }

    String inList(Iterable<Object> values) =>
        '(${placeholders(values).join(', ')})';

    const singleLeg =
        't.transfer_peer_id IS NULL OR t.amount_minor < 0 OR '
        '(t.amount_minor = 0 AND t.id < t.transfer_peer_id)';

    // Accounts and transfer de-duplication.
    if (f.accountIds.isEmpty) {
      parts.add('($singleLeg)');
    } else {
      final ids = f.accountIds.toList()..sort();
      parts.add('t.account_id IN ${inList(ids)}');
      parts.add(
        '($singleLeg OR p.account_id IS NULL OR '
        'p.account_id NOT IN ${inList(ids)})',
      );
    }

    // Search.
    if (f.hasSearch) {
      final fts = ftsQuery(f.search);
      final amount = searchAmount(f.search);
      final alternatives = <String>[];
      if (fts.isNotEmpty) {
        alternatives.add(
          't.rowid IN (SELECT rowid FROM txn_search WHERE txn_search MATCH ?)',
        );
        vars.add(Variable<Object>(fts));
      }
      if (amount != null) {
        alternatives.add('ABS(t.amount_minor) = ?');
        vars.add(Variable<Object>(amount));
      }
      if (alternatives.isNotEmpty) {
        parts.add('(${alternatives.join(' OR ')})');
      }
    }

    if (f.hasPayee) {
      parts.add('t.payee = ? COLLATE NOCASE');
      vars.add(Variable<Object>(f.payee!.trim()));
    }

    if (f.importBatchId != null) {
      parts.add('t.import_batch_id = ?');
      vars.add(Variable<Object>(f.importBatchId));
    }

    // Categories (incl. sub-categories and split lines).
    if (f.hasCategory) {
      final alternatives = <String>[];
      if (f.categoryIds.isNotEmpty) {
        final ids = f.categoryIds.toList()..sort();
        String catSet() =>
            '(SELECT c.id FROM categories c WHERE c.id IN ${inList(ids)} '
            'OR c.parent_id IN ${inList(ids)})';
        alternatives
          ..add('t.category_id IN ${catSet()}')
          ..add(
            'EXISTS (SELECT 1 FROM transaction_splits s '
            'WHERE s.transaction_id = t.id AND s.deleted_at IS NULL '
            'AND s.category_id IN ${catSet()})',
          );
      }
      if (f.uncategorized) {
        alternatives.add(
          '(t.category_id IS NULL AND t.transfer_peer_id IS NULL AND '
          "t.type <> 'transfer' AND NOT EXISTS (SELECT 1 FROM "
          'transaction_splits s2 WHERE s2.transaction_id = t.id '
          'AND s2.deleted_at IS NULL AND s2.category_id IS NOT NULL))',
        );
      }
      parts.add('(${alternatives.join(' OR ')})');
    }

    if (f.tagIds.isNotEmpty) {
      final ids = f.tagIds.toList()..sort();
      parts.add(
        'EXISTS (SELECT 1 FROM transaction_tags tt WHERE '
        'tt.transaction_id = t.id AND tt.deleted_at IS NULL AND '
        'tt.tag_id IN ${inList(ids)})',
      );
    }

    if (f.types.isNotEmpty) {
      parts.add('t.type IN ${inList([for (final x in f.types) x.name])}');
    }
    if (f.statuses.isNotEmpty) {
      parts.add('t.status IN ${inList([for (final x in f.statuses) x.name])}');
    }
    if (f.minAmountMinor != null) {
      parts.add('ABS(t.amount_minor) >= ?');
      vars.add(Variable<Object>(f.minAmountMinor));
    }
    if (f.maxAmountMinor != null) {
      parts.add('ABS(t.amount_minor) <= ?');
      vars.add(Variable<Object>(f.maxAmountMinor));
    }

    final span = f.dateSpan(now);
    if (span != null) {
      parts.add('t.date >= ? AND t.date < ?');
      vars
        ..add(Variable<DateTime>(span.start))
        ..add(Variable<DateTime>(span.end));
    }

    for (final c in f.customFields) {
      const base =
          'SELECT 1 FROM custom_field_values v WHERE v.entity_id = t.id '
          'AND v.deleted_at IS NULL AND v.field_id = ?';
      vars.add(Variable<Object>(c.fieldId));
      switch (c.op) {
        case CustomFieldOp.isSet:
          parts.add('EXISTS ($base)');
        case CustomFieldOp.equals:
          parts.add('EXISTS ($base AND v.value = ?)');
          vars.add(Variable<Object>(jsonEncode(c.value)));
        case CustomFieldOp.contains:
          parts.add("EXISTS ($base AND v.value LIKE ? ESCAPE '\\')");
          vars.add(Variable<Object>('%${_escapeLike('${c.value ?? ''}')}%'));
        case CustomFieldOp.matches:
          final text = '${c.value ?? ''}';
          parts.add(
            'EXISTS ($base AND (v.value = ? OR v.value = ? OR '
            r"v.value LIKE ? ESCAPE '\'))",
          );
          vars
            ..add(Variable<Object>(jsonEncode(text)))
            ..add(Variable<Object>(text))
            ..add(Variable<Object>('[%${_escapeLike(jsonEncode(text))}%]'));
        case CustomFieldOp.includes:
          parts.add("EXISTS ($base AND v.value LIKE ? ESCAPE '\\')");
          vars.add(
            Variable<Object>('%${_escapeLike(jsonEncode('${c.value}'))}%'),
          );
      }
    }

    return SqlPart(parts.join(' AND '), vars);
  }

  static String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}
