import 'package:flutter/widgets.dart';

/// Material 3 window-size classes (PLAN.md §4.1).
enum WindowSize {
  /// < 600: bottom bar + FAB, full-screen details, quick add as sheet.
  compact,

  /// 600–839: navigation rail, list-detail where it helps.
  medium,

  /// ≥ 840: extended rail, list-detail panes, dashboard grid, dialogs.
  expanded;

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) {
    if (width < 600) return compact;
    if (width < 840) return medium;
    return expanded;
  }

  bool get isCompact => this == compact;
  bool get isExpanded => this == expanded;
}
