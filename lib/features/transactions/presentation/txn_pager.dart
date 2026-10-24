import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/features/transactions/data/txn_list_repository.dart';
import 'package:personal_finance/features/transactions/data/txn_query.dart';
import 'package:personal_finance/features/transactions/domain/txn_filter.dart';
import 'package:personal_finance/features/transactions/domain/txn_grouping.dart';

/// One loaded keyset page: rows strictly after [after] and at or before
/// [upTo] (both in sort order). Bounds are values, not rows, so reloading
/// a page after inserts/deletes keeps every row in exactly one page.
class _Page {
  _Page({required this.after, required this.upTo, required this.rows});

  final TxnCursor? after;

  /// Null for the open-ended last page once the end was reached.
  TxnCursor? upTo;
  List<TxnListItem> rows;
}

/// Keyset-paginated, live-updating window over the filtered transaction
/// list. Only the pages the user scrolled to are loaded; any change to the
/// ledger reloads exactly those pages (bounded by their cursors).
class TxnPager extends ChangeNotifier {
  TxnPager({
    required this.repository,
    required this.filter,
    required this.sort,
    required this.grouping,
    required this.firstDayOfWeek,
    this.runningBalance = false,
    this.pageSize = 60,
  }) {
    _sub = repository.changes().listen((_) => _scheduleReload());
    unawaited(loadMore());
  }

  final TxnListRepository repository;
  final TxnFilter filter;
  final TxnSort sort;
  final TxnGrouping grouping;
  final int firstDayOfWeek;
  final bool runningBalance;
  final int pageSize;

  final _pages = <_Page>[];
  StreamSubscription<void>? _sub;
  Timer? _debounce;
  var _generation = 0;
  var _loading = false;
  var _hasMore = true;
  var _disposed = false;
  Object? _error;
  List<TxnListItem> _items = const [];
  Map<DateTime, int> _groupSums = const {};

  List<TxnListItem> get items => _items;
  bool get loading => _loading;
  bool get hasMore => _hasMore;

  /// True until the first page arrived.
  bool get initialLoading => _pages.isEmpty && _error == null;
  Object? get error => _error;

  /// Net sum per group start (only when [groupingApplies]).
  Map<DateTime, int> get groupSums => _groupSums;

  bool get grouped => groupingApplies(grouping, sort);

  /// Loads the next page (no-op while loading or at the end).
  Future<void> loadMore() async {
    if (_loading || !_hasMore || _disposed) return;
    _loading = true;
    final gen = _generation;
    try {
      final after = _pages.isEmpty ? null : _pages.last.upTo;
      final rows = await repository.fetch(
        filter,
        sort: sort,
        after: after,
        limit: pageSize,
        runningBalance: runningBalance,
      );
      if (_disposed || gen != _generation) return;
      final reachedEnd = rows.length < pageSize;
      _pages.add(
        _Page(
          after: after,
          upTo: reachedEnd || rows.isEmpty ? null : rows.last.cursor,
          rows: rows,
        ),
      );
      _hasMore = !reachedEnd;
      _error = null;
      await _rebuild(gen);
    } on Object catch (e) {
      if (_disposed) return;
      _error = e;
      notifyListeners();
    } finally {
      _loading = false;
    }
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 40), () {
      unawaited(reload());
    });
  }

  /// Re-queries all loaded pages within their bounds.
  Future<void> reload() async {
    if (_disposed) return;
    final gen = ++_generation;
    try {
      if (_pages.isEmpty) {
        _hasMore = true;
        _loading = false;
        await loadMore();
        return;
      }
      for (final page in List.of(_pages)) {
        final open = page.upTo == null;
        // Closed pages are bounded by their cursors; a mass insert (import)
        // into one is detected by the cap and answered with a fresh start.
        final cap = pageSize * 4;
        final rows = await repository.fetch(
          filter,
          sort: sort,
          after: page.after,
          upTo: page.upTo,
          limit: open ? pageSize : cap + 1,
          runningBalance: runningBalance,
        );
        if (_disposed || gen != _generation) return;
        if (!open && rows.length > cap) {
          _pages.clear();
          _hasMore = true;
          _loading = false;
          await loadMore();
          return;
        }
        page.rows = rows;
        if (open && rows.length >= pageSize) {
          page.upTo = rows.last.cursor;
          _hasMore = true;
        }
      }
      _error = null;
      await _rebuild(gen);
    } on Object catch (e) {
      if (_disposed || gen != _generation) return;
      _error = e;
      notifyListeners();
    }
  }

  Future<void> _rebuild(int gen) async {
    final all = [for (final p in _pages) ...p.rows];
    var sums = const <DateTime, int>{};
    if (grouped && all.isNotEmpty) {
      final dates = all.map((r) => r.date);
      final minDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);
      final maxDate = dates.reduce((a, b) => a.isAfter(b) ? a : b);
      final start = groupStart(minDate, grouping, firstDayOfWeek);
      final end = groupEnd(
        groupStart(maxDate, grouping, firstDayOfWeek),
        grouping,
      );
      final days = await repository.daySums(filter, start, end);
      if (_disposed || gen != _generation) return;
      sums = sumByGroup(days, grouping, firstDayOfWeek);
    }
    _items = all;
    _groupSums = sums;
    notifyListeners();
  }

  /// Optimistically replaces a row (e.g. status toggled) until the reload.
  void patch(TxnListItem item) {
    final i = _items.indexWhere((r) => r.id == item.id);
    if (i < 0) return;
    for (final p in _pages) {
      final j = p.rows.indexWhere((r) => r.id == item.id);
      if (j >= 0) p.rows = [...p.rows]..[j] = item;
    }
    _items = [..._items]..[i] = item;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
