import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/board/board_layout.dart';
import 'package:personal_finance/core/board/board_storage.dart';
import 'package:personal_finance/core/db/db_providers.dart';
import 'package:personal_finance/core/sync/sync_backend.dart';
import 'package:personal_finance/features/dashboard/data/dashboard_layout.dart';

import 'sync_engine_test.dart' show Device;

const _view = DashboardView.expanded;

void main() {
  test('two devices that each started a layout before they synced settle '
      'on one, and no layout is lost', () async {
    final backend = InMemorySyncBackend();
    final a = Device('device-a', backend);
    final b = Device('device-b', backend);
    addTearDown(() async {
      await a.db.close();
      await b.db.close();
    });
    DashboardLayoutRepository repoOf(Device d) {
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(d.db),
          syncWriterProvider.overrideWithValue(d.writer),
        ],
      );
      addTearDown(c.dispose);
      return c.read(dashboardLayoutRepositoryProvider);
    }

    final ra = repoOf(a);
    final rb = repoOf(b);
    DashboardViewState hide(DashboardViewState s, DashboardWidgetType t) =>
        s.withVisible(_view, t.name, visible: false);

    // B starts a layout and syncs; A starts its own and syncs.
    await rb.update(_view, (s) => hide(s, DashboardWidgetType.goals));
    await b.sync();
    await ra.update(_view, (s) => hide(s, DashboardWidgetType.accounts));
    await a.sync();
    // B edits again and syncs; then each saves before the next sync, A first.
    b.now += 1000;
    await rb.update(_view, (s) => s.copyWith(mode: LayoutMode.custom));
    await b.sync();
    a.now += 2000;
    await ra.update(_view, (s) => hide(s, DashboardWidgetType.budgets));
    b.now += 3000;
    await rb.update(_view, (s) => hide(s, DashboardWidgetType.forecast));
    for (var i = 0; i < 2; i++) {
      await a.sync();
      await b.sync();
    }

    final sa = await ra.read(_view);
    final sb = await rb.read(_view);
    expect(sa, sb);
    // Both devices wrote to the row every device picks; as with any synced
    // data edited on two devices before a sync, the later write wins.
    expect(sa.shows(_view, DashboardWidgetType.forecast.name), isFalse);
    expect(sa.shows(_view, DashboardWidgetType.goals.name), isFalse);
    expect(sa.mode, LayoutMode.custom);
    // No row was moved or deleted: A's first layout is still there.
    final rows = await a.db.select(a.db.dashboardLayouts).get();
    final live = rows.where((r) => r.deletedAt == null).toList();
    expect(live.map((r) => r.breakpoint).toSet(), {storageKey(_view)});
    expect(live, hasLength(2));
    expect(
      live
          .map((r) => decodeViewState(dashboardBoard, _view, r.widgets))
          .any((s) => !s.shows(_view, DashboardWidgetType.accounts.name)),
      isTrue,
    );
  });
}
