/// Rules for the navigation tab editor (pure Dart).
///
/// The bar shows between [minNavTabs] and [maxNavTabs] destinations,
/// counting "More", which is always present and always last.
library;

const minNavTabs = 2;
const maxNavTabs = 5;
const moreTab = 'more';

/// Tabs at least one of which should stay in the bar.
const recommendedTabs = {'home', 'transactions'};

/// Normalises a stored list: drops unknown and duplicate names, moves
/// "more" to the end (adding it when missing) and trims to [maxNavTabs].
List<String> normalizeNavTabs(List<String> tabs, Iterable<String> known) {
  final k = known.toSet();
  final out = <String>[];
  for (final t in tabs) {
    if (t == moreTab || !k.contains(t) || out.contains(t)) continue;
    out.add(t);
  }
  final trimmed = out.take(maxNavTabs - 1).toList()..add(moreTab);
  return trimmed;
}

/// Whether [tab] may be switched on/off given the current [tabs].
bool canToggleNavTab(List<String> tabs, String tab) {
  if (tab == moreTab) return false;
  return tabs.contains(tab)
      ? tabs.length > minNavTabs
      : tabs.length < maxNavTabs;
}

/// Adds or removes [tab]; returns [tabs] unchanged when not allowed.
/// New tabs are inserted just before "More".
List<String> toggleNavTab(List<String> tabs, String tab) {
  if (!canToggleNavTab(tabs, tab)) return tabs;
  if (tabs.contains(tab)) return [...tabs]..remove(tab);
  final out = [...tabs]..remove(moreTab);
  return [...out, tab, moreTab];
}

/// Moves the tab at [from] so it ends up at index [to] (indices into
/// [tabs] without "More", which stays last).
List<String> moveNavTab(List<String> tabs, int from, int to) {
  final movable = [...tabs]..remove(moreTab);
  if (from < 0 || from >= movable.length) return tabs;
  final t = movable.removeAt(from);
  movable.insert(to.clamp(0, movable.length), t);
  return [...movable, moreTab];
}

/// True when neither Home nor Transactions is in the bar.
bool lacksRecommendedTab(List<String> tabs) =>
    !tabs.any(recommendedTabs.contains);
