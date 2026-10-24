import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/ui/formatters.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/settings_controller.dart';
import 'package:personal_finance/features/transactions/data/txn_list_repository.dart';
import 'package:personal_finance/features/transactions/domain/txn_filter.dart';
import 'package:personal_finance/features/transactions/domain/txn_grouping.dart';
import 'package:personal_finance/features/transactions/presentation/quick_add.dart';
import 'package:personal_finance/features/transactions/presentation/swipe_actions.dart';
import 'package:personal_finance/features/transactions/presentation/transaction_tile.dart';
import 'package:personal_finance/features/transactions/presentation/txn_labels.dart';
import 'package:personal_finance/features/transactions/presentation/txn_pager.dart';
import 'package:personal_finance/features/transactions/presentation/txn_ui_actions.dart';

/// Selection, keyboard focus and detail state shared between a
/// [TransactionListView] and its host screen.
class TxnListController extends ChangeNotifier {
  final Set<String> _selected = {};
  var _selectionMode = false;
  String? _focusedId;
  String? _openId;
  List<TxnListItem> _items = const [];

  /// Keyboard focus for the list (Up/Down/Enter/Delete/Ctrl+D).
  final FocusNode focusNode = FocusNode(debugLabel: 'txn-list');

  Set<String> get selected => _selected;
  bool get selectionMode => _selectionMode;
  String? get focusedId => _focusedId;

  /// Row shown in the detail pane.
  String? get openId => _openId;

  /// Currently loaded rows (in display order).
  List<TxnListItem> get items => _items;

  List<TxnListItem> get selectedItems =>
      _items.where((i) => _selected.contains(i.id)).toList();

  void startSelection([String? id]) {
    _selectionMode = true;
    if (id != null) _selected.add(id);
    notifyListeners();
  }

  void toggle(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    _selectionMode = _selected.isNotEmpty || _selectionMode;
    notifyListeners();
  }

  void selectAll() {
    _selected.addAll(_items.map((i) => i.id));
    _selectionMode = true;
    notifyListeners();
  }

  void clearSelection() {
    if (_selected.isEmpty && !_selectionMode) return;
    _selected.clear();
    _selectionMode = false;
    notifyListeners();
  }

  void focus(String? id) {
    if (_focusedId == id) return;
    _focusedId = id;
    notifyListeners();
  }

  void open(String? id) {
    if (_openId == id) return;
    _openId = id;
    notifyListeners();
  }

  void _setItems(List<TxnListItem> items) {
    _items = items;
    final ids = items.map((i) => i.id).toSet();
    final before = _selected.length;
    _selected.removeWhere((id) => !ids.contains(id));
    if (_selected.length != before) {
      scheduleMicrotask(notifyListeners);
    }
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }
}

/// Live, keyset-paginated transaction list for a [TxnFilter], grouped and
/// sorted per Settings › Transactions. Virtualised; loads more rows while
/// scrolling.
///
/// Embeddable in other screens (e.g. an account's detail page) with
/// `embedded: true`; it must get a bounded height (e.g. inside
/// `Expanded`). Tapping a row then opens `/transactions/:id`.
///
/// Touch: swipe right toggles cleared, swipe left offers duplicate/delete,
/// long-press starts multi-select. Desktop: right-click context menu,
/// keyboard (Up/Down, Enter, Delete, Ctrl/Cmd+D, Space, Ctrl/Cmd+A, Esc).
class TransactionListView extends ConsumerStatefulWidget {
  const TransactionListView({
    super.key,
    this.filter = TxnFilter.empty,
    this.embedded = false,
    this.controller,
    this.onOpen,
    this.onClearFilters,
    this.padding = EdgeInsets.zero,
    this.tableAllowed = true,
  });

  final TxnFilter filter;

  /// No table layout; tapping a row pushes the detail route.
  final bool embedded;
  final TxnListController? controller;

  /// Called when a row is opened (tap / Enter). Default: push detail.
  final ValueChanged<TxnListItem>? onOpen;

  /// Shown as action on the "no matches" empty state.
  final VoidCallback? onClearFilters;
  final EdgeInsets padding;

  /// Use the column table on wide layouts (≥ 640 px).
  final bool tableAllowed;

  @override
  ConsumerState<TransactionListView> createState() =>
      _TransactionListViewState();
}

typedef _PagerKey = ({
  TxnFilter filter,
  TxnSort sort,
  TxnGrouping grouping,
  int firstDay,
  bool balance,
});

/// A row of the flattened list: a group header or a transaction.
class _Entry {
  const _Entry.header(this.groupStart) : index = -1;
  const _Entry.row(this.index) : groupStart = null;

  final DateTime? groupStart;
  final int index;

  bool get isHeader => groupStart != null;
}

class _TransactionListViewState extends ConsumerState<TransactionListView> {
  TxnPager? _pager;
  _PagerKey? _key;
  TxnListController? _ownController;
  final _scroll = ScrollController();
  List<_Entry> _entries = const [];
  var _table = false;

  TxnListController get _ctrl =>
      widget.controller ?? (_ownController ??= TxnListController());

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(TransactionListView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _ownController)?.removeListener(_onControllerChange);
      _ctrl.addListener(_onControllerChange);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChange);
    _ownController?.dispose();
    _pager?.removeListener(_onPager);
    _pager?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  void _onPager() {
    if (!mounted) return;
    _ctrl._setItems(_pager!.items);
    setState(() {});
    // Fill the viewport if the first page is shorter than the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = _pager;
      if (!mounted || p == null || !_scroll.hasClients) return;
      if (p.hasMore && _scroll.position.maxScrollExtent <= 0) {
        unawaited(p.loadMore());
      }
    });
  }

  void _ensurePager(_PagerKey key) {
    if (_key == key && _pager != null) return;
    _pager?.removeListener(_onPager);
    _pager?.dispose();
    _key = key;
    _pager = TxnPager(
      repository: ref.read(txnListRepositoryProvider),
      filter: key.filter,
      sort: key.sort,
      grouping: key.grouping,
      firstDayOfWeek: key.firstDay,
      runningBalance: key.balance,
    )..addListener(_onPager);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  // ---------------------------------------------------------- entries ---

  List<_Entry> _buildEntries(TxnPager p) {
    final items = p.items;
    if (!p.grouped) {
      return [for (var i = 0; i < items.length; i++) _Entry.row(i)];
    }
    final out = <_Entry>[];
    DateTime? current;
    for (var i = 0; i < items.length; i++) {
      final g = groupStart(items[i].date, p.grouping, p.firstDayOfWeek);
      if (g != current) {
        out.add(_Entry.header(g));
        current = g;
      }
      out.add(_Entry.row(i));
    }
    return out;
  }

  double _extent(_Entry e) => e.isHeader
      ? (_table ? 30 : 36)
      : (_table ? kTxnTableRowHeight : kTxnTileHeight);

  void _scrollToItem(int itemIndex) {
    if (!_scroll.hasClients) return;
    var offset = 0.0;
    double? height;
    for (final e in _entries) {
      if (!e.isHeader && e.index == itemIndex) {
        height = _extent(e);
        break;
      }
      offset += _extent(e);
    }
    if (height == null) return;
    final pos = _scroll.position;
    final top = pos.pixels;
    final bottom = top + pos.viewportDimension;
    if (offset < top) {
      _scroll.jumpTo(math.max(0, offset - (_table ? 30 : 36)));
    } else if (offset + height > bottom) {
      _scroll.jumpTo(
        math.min(pos.maxScrollExtent, offset + height - pos.viewportDimension),
      );
    }
  }

  // ---------------------------------------------------------- actions ---

  void _open(TxnListItem item) {
    _ctrl.focus(item.id);
    if (widget.onOpen != null) {
      widget.onOpen!(item);
    } else {
      unawaited(context.push('/transactions/${item.id}'));
    }
  }

  void _tap(TxnListItem item) {
    if (_ctrl.selectionMode) {
      _ctrl.toggle(item.id);
      return;
    }
    if (_table) _ctrl.focusNode.requestFocus();
    _open(item);
  }

  List<String> _targetIds(TxnListItem? fallback) {
    final sel = _ctrl.selected;
    if (sel.isNotEmpty) return sel.toList();
    return [?fallback?.id];
  }

  Future<void> _delete(List<String> ids) async {
    final ok = await deleteTransactionsWithUndo(context, ref, ids);
    if (ok) {
      _ctrl.clearSelection();
      if (ids.contains(_ctrl.openId)) _ctrl.open(null);
    }
  }

  Future<void> _contextMenu(TxnListItem item, Offset global) async {
    final l = context.l10n;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(global.dx, global.dy, 1, 1),
      Offset.zero & overlay.size,
    );
    final cleared = item.status == TxnStatus.cleared;
    final action = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          value: 'open',
          child: _MenuRow(Icons.open_in_new, l.txnOpen),
        ),
        PopupMenuItem(
          value: 'edit',
          child: _MenuRow(Icons.edit_outlined, l.commonEdit),
        ),
        PopupMenuItem(
          value: 'duplicate',
          child: _MenuRow(
            Icons.copy_outlined,
            l.txnDuplicate,
            shortcut: '${TxnLabels.modifier(l)}+D',
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: _MenuRow(
            cleared ? Icons.schedule : Icons.check_circle_outline,
            cleared ? l.txnMarkPending : l.txnMarkCleared,
          ),
        ),
        PopupMenuItem(
          value: 'template',
          child: _MenuRow(Icons.bookmark_add_outlined, l.txnSaveAsTemplate),
        ),
        PopupMenuItem(
          value: 'select',
          child: _MenuRow(Icons.checklist, l.txnSelect),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _MenuRow(
            Icons.delete_outline,
            l.commonDelete,
            shortcut: l.txnKeyDelete,
            destructive: true,
          ),
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        _open(item);
      case 'edit':
        await showQuickAdd(context, editId: item.id);
      case 'duplicate':
        await duplicateInQuickAdd(context, ref, item.id);
      case 'toggle':
        await toggleClearedWithUndo(context, ref, item.id);
      case 'template':
        await saveAsTemplate(context, ref, item.id);
      case 'select':
        _ctrl.startSelection(item.id);
      case 'delete':
        await _delete(
          _ctrl.selected.contains(item.id) ? _targetIds(item) : [item.id],
        );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final items = _pager?.items ?? const <TxnListItem>[];
    if (items.isEmpty) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final mod = keys.isControlPressed || keys.isMetaPressed;
    final k = e.logicalKey;
    final index = items.indexWhere((i) => i.id == _ctrl.focusedId);
    final focused = index >= 0 ? items[index] : null;

    void moveTo(int i) {
      final next = i.clamp(0, items.length - 1);
      _ctrl.focus(items[next].id);
      _scrollToItem(next);
      if (!_ctrl.selectionMode && widget.onOpen != null && _table) {
        widget.onOpen!(items[next]);
      }
      if (next >= items.length - 10) unawaited(_pager?.loadMore());
    }

    if (k == LogicalKeyboardKey.arrowDown) {
      moveTo(index < 0 ? 0 : index + 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      moveTo(index < 0 ? 0 : index - 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.home) {
      moveTo(0);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.end) {
      moveTo(items.length - 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      if (_ctrl.selectionMode) {
        _ctrl.clearSelection();
        return KeyEventResult.handled;
      }
      if (_ctrl.openId != null) {
        _ctrl.open(null);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (mod && k == LogicalKeyboardKey.keyA) {
      _ctrl.selectAll();
      return KeyEventResult.handled;
    }
    if (focused == null) {
      if (k == LogicalKeyboardKey.delete && _ctrl.selected.isNotEmpty) {
        unawaited(_delete(_targetIds(null)));
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (mod) return KeyEventResult.ignored;
      _open(focused);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.space) {
      _ctrl.toggle(focused.id);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.delete ||
        (k == LogicalKeyboardKey.backspace && keys.isMetaPressed)) {
      unawaited(_delete(_targetIds(focused)));
      return KeyEventResult.handled;
    }
    if (mod && k == LogicalKeyboardKey.keyD) {
      unawaited(duplicateInQuickAdd(context, ref, focused.id));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.f2 || (mod && k == LogicalKeyboardKey.keyE)) {
      unawaited(showQuickAdd(context, editId: focused.id));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------ build ---

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final sort = settings.get(TransactionSettings.sort);
    final grouping = settings.get(TransactionSettings.grouping);
    final columns = [
      for (final n in settings.get(TransactionSettings.visibleColumns))
        ?TxnColumn.values.where((c) => c.name == n).firstOrNull,
    ];
    final balanceWanted =
        settings.get(TransactionSettings.runningBalance) ||
        columns.contains(TxnColumn.balance);
    final balance =
        balanceWanted &&
        TxnListRepository.runningBalanceApplies(widget.filter, sort);
    final firstDay = ref.watch(firstDayOfWeekProvider);
    _ensurePager((
      filter: widget.filter,
      sort: sort,
      grouping: grouping,
      firstDay: firstDay,
      balance: balance,
    ));
    final pager = _pager!;
    final dates = ref.watch(dateFormatsProvider);
    final tagsOn = settings.moduleEnabled(AppModule.tags);

    if (pager.error != null && pager.items.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        message: l.commonError('${pager.error}'),
        actionLabel: l.commonRetry,
        onAction: () => unawaited(pager.reload()),
      );
    }
    if (pager.initialLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (pager.items.isEmpty) {
      final filtered = !widget.filter.isEmpty;
      return EmptyState(
        icon: filtered
            ? Icons.filter_alt_off_outlined
            : Icons.receipt_long_outlined,
        message: filtered ? l.txnEmptyFiltered : l.txnEmpty,
        actionLabel: filtered && widget.onClearFilters != null
            ? l.txnClearFilters
            : null,
        onAction: widget.onClearFilters,
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        _table = widget.tableAllowed && !widget.embedded && box.maxWidth >= 640;
        _entries = _buildEntries(pager);
        final items = pager.items;
        var tableColumns = [
          for (final c in columns)
            if (c != TxnColumn.tags || tagsOn)
              if (c != TxnColumn.balance || balance) c,
        ];
        if (balance && !tableColumns.contains(TxnColumn.balance)) {
          tableColumns = [...tableColumns, TxnColumn.balance];
        }
        if (!tableColumns.contains(TxnColumn.amount)) {
          tableColumns = [...tableColumns, TxnColumn.amount];
        }
        final layout = TxnTableLayout(tableColumns);
        final footer = pager.hasMore ? 1 : 0;

        Widget itemBuilder(BuildContext context, int i) {
          if (i >= _entries.length) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final e = _entries[i];
          if (e.isHeader) {
            return TxnGroupHeader(
              label: TxnLabels.groupHeader(
                l,
                dates,
                e.groupStart!,
                pager.grouping,
              ),
              sum: pager.groupSums[e.groupStart],
              height: _table ? 30 : 36,
              leftInset: _table ? 44 : 20,
            );
          }
          final item = items[e.index];
          final prevIsRow = i > 0 && !_entries[i - 1].isHeader;
          final focused =
              _ctrl.focusedId == item.id && _ctrl.focusNode.hasFocus;
          if (_table) {
            return TxnTableRow(
              key: ValueKey(item.id),
              item: item,
              layout: layout,
              divider: prevIsRow,
              selected: _ctrl.openId == item.id,
              checked: _ctrl.selected.contains(item.id),
              focused: focused,
              onTap: () => _tap(item),
              onCheck: (_) {
                _ctrl.focusNode.requestFocus();
                _ctrl.toggle(item.id);
              },
              onSecondaryTapDown: (d) => _contextMenu(item, d.globalPosition),
            );
          }
          final cleared = item.status == TxnStatus.cleared;
          final cs = context.colors;
          final tile = TransactionTile(
            item: item,
            divider: prevIsRow,
            selected:
                _ctrl.selected.contains(item.id) || _ctrl.openId == item.id,
            selectionMode: _ctrl.selectionMode,
            focused: focused,
            showBalance: balance,
            showDate: !pager.grouped,
            onTap: () => _tap(item),
            onLongPress: () => _ctrl.startSelection(item.id),
            onSecondaryTapDown: (d) => _contextMenu(item, d.globalPosition),
          );
          return SwipeActions(
            key: ValueKey(item.id),
            enabled: !_ctrl.selectionMode,
            start: [
              SwipeAction(
                icon: cleared ? Icons.schedule : Icons.check_circle_outline,
                label: cleared ? l.txnMarkPending : l.txnMarkCleared,
                background: cs.primaryContainer,
                foreground: cs.onPrimaryContainer,
                onTap: () => toggleClearedWithUndo(context, ref, item.id),
              ),
            ],
            end: [
              SwipeAction(
                icon: Icons.copy_outlined,
                label: l.txnDuplicate,
                onTap: () => duplicateInQuickAdd(context, ref, item.id),
              ),
              SwipeAction(
                icon: Icons.delete_outline,
                label: l.commonDelete,
                background: cs.errorContainer,
                foreground: cs.onErrorContainer,
                onTap: () => _delete([item.id]),
              ),
            ],
            child: tile,
          );
        }

        final list = NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 800 && pager.hasMore) {
              unawaited(pager.loadMore());
            }
            return false;
          },
          child: Scrollbar(
            controller: _scroll,
            child: ListView.builder(
              controller: _scroll,
              padding: widget.padding,
              itemCount: _entries.length + footer,
              // Must return null past the end, or the sliver never stops.
              itemExtentBuilder: (i, _) => i < _entries.length
                  ? _extent(_entries[i])
                  : (i < _entries.length + footer ? 56 : null),
              itemBuilder: itemBuilder,
            ),
          ),
        );

        final selectedLoaded = items
            .where((i) => _ctrl.selected.contains(i.id))
            .length;
        final body = _table
            ? Column(
                children: [
                  TxnTableHeader(
                    layout: layout,
                    allSelected: selectedLoaded == 0
                        ? false
                        : selectedLoaded == items.length
                        ? true
                        : null,
                    onSelectAll: (all) =>
                        all ? _ctrl.selectAll() : _ctrl.clearSelection(),
                  ),
                  Expanded(child: list),
                ],
              )
            : list;

        return Focus(
          focusNode: _ctrl.focusNode,
          onKeyEvent: _onKey,
          onFocusChange: (_) => setState(() {}),
          child: body,
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(
    this.icon,
    this.label, {
    this.shortcut,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? shortcut;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final color = destructive ? cs.error : cs.onSurface;
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: destructive ? cs.error : cs.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: TextStyle(color: color)),
        ),
        if (shortcut != null) ...[
          const SizedBox(width: 16),
          Text(
            shortcut!,
            style: context.mono.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
