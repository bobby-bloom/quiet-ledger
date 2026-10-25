import 'package:flutter/widgets.dart';

/// What a board calls itself and its cards (docs/BOARD.md). The words of
/// the board's structure — rows, splits, moves — are the same everywhere
/// (`board*` strings); these name the screen and what sits on it, e.g.
/// "Arrange widgets" and "Remove from dashboard" on Home.
@immutable
class BoardLabels {
  const BoardLabels({
    required this.menu,
    required this.menuCustom,
    required this.autoHint,
    required this.customHint,
    required this.orderAutoHint,
    required this.orderCustomHint,
    required this.arrangeMenu,
    required this.arrangeTitle,
    required this.addMenu,
    required this.addTitle,
    required this.emptyColumn,
    required this.removeFromBoard,
    required this.notOnBoard,
    required this.orderTitle,
    required this.resetDone,
    required this.cardName,
    required this.cardTitle,
    required this.cardIcon,
    required this.cardDescription,
  });

  /// The layout button's tooltip, and the same while not on Auto.
  final String menu;
  final String menuCustom;

  /// The line under the Layout control: whose arrangement shows, wide and
  /// in the one-column order.
  final String autoHint;
  final String customHint;
  final String orderAutoHint;
  final String orderCustomHint;

  /// "Arrange widgets…" in the menu, "Arrange widgets" in its bar.
  final String arrangeMenu;
  final String arrangeTitle;

  /// "Add widget…" in the menu, "Add widget" as the sheet's title and in
  /// the arrange bar.
  final String addMenu;
  final String addTitle;

  /// An empty column in arrange mode, e.g. "Drag a widget here".
  final String emptyColumn;

  /// The last item of a card's Move menu, e.g. "Remove from dashboard".
  final String removeFromBoard;

  /// The order sheet's section of cards not shown, and its title.
  final String notOnBoard;
  final String orderTitle;

  /// The toast after the board went back to its defaults.
  final String resetDone;

  /// A card's name where it is arranged — arrange mode, the order sheet —
  /// with what tells it apart ("Mini forecast · Everyday checking"); its
  /// plain name for Add, hidden cards and toasts ("Mini forecast"); its
  /// icon; what it shows, one line for the Add sheet.
  final String Function(String id) cardName;
  final String Function(String id) cardTitle;
  final IconData Function(String id) cardIcon;
  final String Function(String id) cardDescription;
}
