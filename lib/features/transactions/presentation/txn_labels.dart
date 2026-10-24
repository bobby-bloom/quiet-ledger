import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/finance_colors.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/app_icons.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/transactions/data/txn_list_repository.dart';
import 'package:personal_finance/features/transactions/domain/txn_filter.dart';
import 'package:personal_finance/features/transactions/domain/txn_grouping.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Shared label/visual helpers of the transactions feature.
abstract final class TxnLabels {
  static String status(AppLocalizations l, TxnStatus s) => switch (s) {
    TxnStatus.cleared => l.statusCleared,
    TxnStatus.pending => l.statusPending,
    TxnStatus.planned => l.statusPlanned,
  };

  static String type(AppLocalizations l, TxnType t) => switch (t) {
    TxnType.expense => l.typeExpense,
    TxnType.income => l.typeIncome,
    TxnType.transfer => l.typeTransfer,
  };

  static String preset(AppLocalizations l, DatePreset p) => switch (p) {
    DatePreset.thisMonth => l.txnPresetThisMonth,
    DatePreset.lastMonth => l.txnPresetLastMonth,
    DatePreset.last30Days => l.txnPresetLast30,
    DatePreset.last90Days => l.txnPresetLast90,
    DatePreset.thisYear => l.txnPresetThisYear,
    DatePreset.lastYear => l.txnPresetLastYear,
    DatePreset.custom => l.txnPresetCustom,
  };

  static String sort(AppLocalizations l, TxnSort s) => switch (s) {
    TxnSort.dateDesc => l.setOptNewestFirst,
    TxnSort.dateAsc => l.setOptOldestFirst,
    TxnSort.amountDesc => l.setOptLargestFirst,
    TxnSort.amountAsc => l.setOptSmallestFirst,
    TxnSort.payee => l.fieldPayee,
  };

  static String grouping(AppLocalizations l, TxnGrouping g) => switch (g) {
    TxnGrouping.day => l.setOptDay,
    TxnGrouping.week => l.setOptWeek,
    TxnGrouping.month => l.setOptMonth,
    TxnGrouping.none => l.commonNone,
  };

  /// Row title: payee, else "To/From account" for transfers, else note,
  /// else category.
  static String title(
    AppLocalizations l,
    TxnListItem t, {
    required Map<String, Account> accounts,
    required Map<String, Category> categories,
  }) {
    final payee = t.payee?.trim();
    if (payee != null && payee.isNotEmpty) return payee;
    if (t.isTransfer) {
      final peer = accounts[t.peerAccountId]?.name ?? l.txnUnknownAccount;
      return t.amountMinor > 0
          ? l.txnTransferFrom(peer)
          : l.txnTransferTo(peer);
    }
    final note = t.note?.trim();
    if (note != null && note.isNotEmpty) return note;
    final c = categories[t.categoryId];
    if (c != null) return c.name;
    return l.txnNoPayee;
  }

  /// Category label (or "Split · n", "Transfer", "Uncategorized").
  static String categoryLabel(
    AppLocalizations l,
    TxnListItem t,
    Map<String, Category> categories,
  ) {
    if (t.isTransfer) return l.typeTransfer;
    if (t.isSplit) return l.txnSplitCount(t.splitCount);
    final c = categories[t.categoryId];
    return c == null ? l.txnUncategorized : categoryPath(c, categories);
  }

  /// Row subtitle: "Category · Account" or "Transfer · from Account".
  static String subtitle(
    AppLocalizations l,
    TxnListItem t, {
    required Map<String, Account> accounts,
    required Map<String, Category> categories,
    bool showAccount = true,
  }) {
    final account = accounts[t.accountId]?.name ?? l.txnUnknownAccount;
    if (t.isTransfer) {
      return t.amountMinor > 0
          ? l.txnTransferToSub(account)
          : l.txnTransferFromSub(account);
    }
    final cat = categoryLabel(l, t, categories);
    return showAccount ? '$cat · $account' : cat;
  }

  /// "Today, 23 Oct" / "Yesterday, 22 Oct" / "Tue, 20 Oct" (+ year when not
  /// the current year).
  static String relativeDate(
    AppLocalizations l,
    DateFormats f,
    DateTime d, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return l.txnTodayDate(f.dayMonth(day));
    if (diff == 1) return l.txnYesterdayDate(f.dayMonth(day));
    return day.year == n.year ? f.dayHeader(day) : f.medium(day);
  }

  /// Group header text for the group starting at [start].
  static String groupHeader(
    AppLocalizations l,
    DateFormats f,
    DateTime start,
    TxnGrouping grouping, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    switch (grouping) {
      case TxnGrouping.day:
      case TxnGrouping.none:
        final today = DateTime(n.year, n.month, n.day);
        final diff = today.difference(start).inDays;
        final label = start.year == n.year
            ? f.dayHeader(start)
            : f.medium(start);
        if (diff == 0) return l.txnGroupToday(label);
        if (diff == 1) return l.txnGroupYesterday(label);
        return label;
      case TxnGrouping.week:
        final end = groupEnd(start, grouping);
        final last = DateTime(end.year, end.month, end.day - 1);
        return '${f.dayMonth(start)} – ${last.year == n.year ? f.dayMonth(last) : f.medium(last)}';
      case TxnGrouping.month:
        return f.monthYear(start);
    }
  }

  /// Avatar icon and colour for a row.
  static (IconData, Color) avatar(
    BuildContext context,
    TxnListItem t,
    Map<String, Category> categories,
  ) {
    final fin = context.finance;
    if (t.isTransfer) return (Icons.swap_horiz, fin.transfer);
    if (t.isSplit) return (Icons.call_split, context.colors.secondary);
    final c = categories[t.categoryId];
    if (c != null) {
      return (
        AppIcons.of(c.icon),
        c.color == null ? _kindColor(fin, context, c.kind) : Color(c.color!),
      );
    }
    return (
      t.amountMinor > 0 ? Icons.south_west : Icons.north_east,
      t.amountMinor > 0 ? fin.income : context.colors.secondary,
    );
  }

  static Color _kindColor(FinanceColors fin, BuildContext c, CategoryKind k) =>
      k == CategoryKind.income ? fin.income : c.colors.primary;

  /// "Ctrl" / "Strg" or "⌘" for keyboard hints.
  static String modifier(AppLocalizations l) =>
      defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.iOS
      ? '⌘'
      : l.txnCtrl;
}

extension DayMonthFormat on DateFormats {
  /// e.g. "23 Oct" / "23. Okt.".
  String dayMonth(DateTime d) => DateFormat.MMMd(locale).format(d);
}
