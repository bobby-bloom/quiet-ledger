import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/core/ledger/txn_draft.dart';
import 'package:personal_finance/features/rules/domain/rule_model.dart';

/// How actions treat fields that already have a value.
enum RuleApplyMode {
  /// Only fill empty fields (unless a rule is marked "overwrite").
  fillEmpty,

  /// Replace existing values (used by "re-run on all transactions").
  overwrite,
}

/// Fields a rule can change.
enum RuleField { category, tags, customFields, payee, status, note }

/// Result of applying rules to one draft.
@immutable
class RuleOutcome {
  const RuleOutcome(this.draft, this.matchedRuleIds, this.changed);

  final TxnDraft draft;

  /// Ids (or names for unsaved rules) of all rules whose conditions matched,
  /// in priority order.
  final List<String> matchedRuleIds;

  /// Fields whose value actually changed.
  final Set<RuleField> changed;

  bool get hasChanges => changed.isNotEmpty;
}

/// Pure rule evaluation. Rules run in priority order; for every field the
/// first matching rule that sets it wins.
class RuleEngine {
  RuleEngine(Iterable<RuleDef> rules)
    : rules = [
        for (final r in rules)
          if (r.enabled) r,
      ]..sort(compareRules);

  final List<RuleDef> rules;
  final Map<String, RegExp?> _regexCache = {};

  static int compareRules(RuleDef a, RuleDef b) {
    final p = a.priority.compareTo(b.priority);
    return p != 0 ? p : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  /// Whether [rule]'s conditions match [draft]. A rule without usable
  /// conditions never matches.
  bool matches(RuleDef rule, TxnDraft draft) {
    final conditions = rule.conditions.effective;
    if (conditions.isEmpty) return false;
    return switch (rule.conditions.mode) {
      MatchMode.all => conditions.every((c) => _test(c, draft)),
      MatchMode.any => conditions.any((c) => _test(c, draft)),
    };
  }

  bool _test(RuleCondition c, TxnDraft d) {
    switch (c) {
      case TextCondition():
        final r = switch (c.field) {
          RuleTextField.payee => _text(c, d.payee),
          RuleTextField.note => _text(c, d.note),
          RuleTextField.payeeOrNote => _text(c, d.payee) || _text(c, d.note),
        };
        return c.negate ? !r : r;
      case AmountCondition():
        final v = c.absolute ? d.amountMinor.abs() : d.amountMinor;
        if (c.minMinor != null && v < c.minMinor!) return false;
        if (c.maxMinor != null && v > c.maxMinor!) return false;
        return true;
      case AccountCondition():
        return c.accountIds.contains(d.accountId) ||
            (d.transferAccountId != null &&
                c.accountIds.contains(d.transferAccountId));
      case TypeCondition():
        return c.types.contains(d.type);
    }
  }

  bool _text(TextCondition c, String? raw) {
    final text = (raw ?? '').trim();
    if (c.operator == TextOperator.regex) {
      final re = _regexCache.putIfAbsent(c.value, () {
        try {
          return RegExp(c.value, caseSensitive: false, unicode: true);
        } on FormatException {
          return null;
        }
      });
      return re != null && re.hasMatch(text);
    }
    final t = text.toLowerCase();
    final v = c.value.trim().toLowerCase();
    return switch (c.operator) {
      TextOperator.contains => t.contains(v),
      TextOperator.equals => t == v,
      TextOperator.startsWith => t.startsWith(v),
      TextOperator.endsWith => t.endsWith(v),
      TextOperator.regex => false,
    };
  }

  /// Applies all matching rules to [draft].
  RuleOutcome apply(
    TxnDraft draft, {
    RuleApplyMode mode = RuleApplyMode.fillEmpty,
  }) {
    var d = draft;
    final matched = <String>[];
    final changed = <RuleField>{};
    final decided = <RuleField>{};
    final decidedFields = <String>{};
    final canCategorise = !d.isTransfer && !d.isSplit;

    for (final rule in rules) {
      if (!matches(rule, d)) continue;
      matched.add(rule.id ?? rule.name);
      final a = rule.actions;
      final force = a.overwrite || mode == RuleApplyMode.overwrite;

      if (a.categoryId != null &&
          canCategorise &&
          !decided.contains(RuleField.category)) {
        decided.add(RuleField.category);
        if ((d.categoryId == null || force) && d.categoryId != a.categoryId) {
          d = d.copyWith(categoryId: a.categoryId);
          changed.add(RuleField.category);
        }
      }
      if (a.addTagIds.isNotEmpty && !decided.contains(RuleField.tags)) {
        decided.add(RuleField.tags);
        final missing = a.addTagIds.where((t) => !d.tagIds.contains(t));
        if (missing.isNotEmpty) {
          d = d.copyWith(tagIds: [...d.tagIds, ...missing]);
          changed.add(RuleField.tags);
        }
      }
      if (a.customFields.isNotEmpty) {
        var fields = d.customFields;
        for (final e in a.customFields.entries) {
          if (e.value == null || !decidedFields.add(e.key)) continue;
          final current = fields[e.key];
          final empty = current == null || (current is String && current == '');
          if ((empty || force) && current != e.value) {
            fields = {...fields, e.key: e.value};
          }
        }
        if (!identical(fields, d.customFields)) {
          d = d.copyWith(customFields: fields);
          changed.add(RuleField.customFields);
        }
      }
      final payee = a.payee?.trim();
      if (payee != null &&
          payee.isNotEmpty &&
          !decided.contains(RuleField.payee)) {
        decided.add(RuleField.payee);
        if (d.payee != payee) {
          d = d.copyWith(payee: payee);
          changed.add(RuleField.payee);
        }
      }
      if (a.status != null && !decided.contains(RuleField.status)) {
        decided.add(RuleField.status);
        // `cleared` is the default and counts as "not set".
        if ((d.status == TxnStatus.cleared || force) && d.status != a.status) {
          d = d.copyWith(status: a.status);
          changed.add(RuleField.status);
        }
      }
      final note = a.note?.trim();
      if (note != null &&
          note.isNotEmpty &&
          !decided.contains(RuleField.note)) {
        decided.add(RuleField.note);
        final empty = d.note == null || d.note!.trim().isEmpty;
        if ((empty || force) && d.note != note) {
          d = d.copyWith(note: note);
          changed.add(RuleField.note);
        }
      }
    }
    return RuleOutcome(d, matched, changed);
  }
}
