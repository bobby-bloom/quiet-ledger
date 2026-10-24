import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_finance/app/theme/theme_ext.dart';
import 'package:personal_finance/app/theme/tokens.dart';
import 'package:personal_finance/app/ui/breakpoints.dart';
import 'package:personal_finance/app/ui/pickers.dart';
import 'package:personal_finance/app/ui/widgets.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/ledger/lookups.dart';

/// Picks several tags (with search). Returns the selected ids, or null when
/// dismissed. Archived tags are hidden unless already selected.
Future<Set<String>?> showTagMultiPicker(
  BuildContext context, {
  Set<String> selected = const {},
}) => showAdaptiveSheet<Set<String>>(
  context,
  builder: (_) => TagMultiPicker(selected: selected),
);

class TagMultiPicker extends ConsumerStatefulWidget {
  const TagMultiPicker({required this.selected, super.key});

  final Set<String> selected;

  @override
  ConsumerState<TagMultiPicker> createState() => _TagMultiPickerState();
}

class _TagMultiPickerState extends ConsumerState<TagMultiPicker> {
  late final Set<String> _selected = {...widget.selected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = _query.toLowerCase();
    final tags = (ref.watch(tagsProvider).value ?? const <Tag>[])
        .where((t) => !t.archived || widget.selected.contains(t.id))
        .where((t) => q.isEmpty || t.name.toLowerCase().contains(q))
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.xs,
            Space.md,
            Space.xs,
          ),
          child: TextField(
            autofocus: !WindowSize.of(context).isCompact,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.commonSearch,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(Radii.full)),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Flexible(
          child: tags.isEmpty
              ? EmptyState(
                  icon: Icons.sell_outlined,
                  message: l.settingsUiNoTags,
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in tags)
                      CheckboxListTile(
                        value: _selected.contains(t.id),
                        onChanged: (_) => setState(
                          () => _selected.contains(t.id)
                              ? _selected.remove(t.id)
                              : _selected.add(t.id),
                        ),
                        secondary: Icon(
                          Icons.sell_outlined,
                          color: t.color == null ? null : Color(t.color!),
                        ),
                        title: Text('#${t.name}'),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.commonCancel),
              ),
              const SizedBox(width: Space.xs),
              FilledButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: Text(l.commonDone),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
