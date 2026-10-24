import 'dart:async';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/features/export/data/safety_copies.dart';
import 'package:personal_finance/features/import/data/import_repository.dart';
import 'package:personal_finance/features/import/data/import_service.dart';
import 'package:personal_finance/features/import/data/profile_repository.dart';
import 'package:personal_finance/features/import/domain/import_analysis.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/import_drafts.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/row_parser.dart';
import 'package:personal_finance/features/import/domain/source_reader.dart';

/// Wizard steps (PLAN.md §2.5).
enum ImportStep {
  source,
  sheets,
  structure,
  mapping,
  formats,
  categories,
  transfers,
  duplicates,
  summary,
}

/// A file or paste of the batch.
@immutable
class LoadedSource {
  const LoadedSource({
    required this.source,
    this.workbook,
    this.error,
    this.csv = const CsvReadOptions(),
  });

  final ImportSource source;
  final RawWorkbook? workbook;
  final ImportReadException? error;
  final CsvReadOptions csv;

  bool get isCsv =>
      workbook?.format == SourceFormat.csv ||
      workbook?.format == SourceFormat.clipboard;
}

@immutable
class ImportWizardState {
  const ImportWizardState({
    this.step = ImportStep.source,
    this.sources = const [],
    this.config = const ImportConfig(),
    this.profileId,
    this.profileName,
    this.selectedSheet,
    this.context,
    this.analysis,
    this.analysedConfig,
    this.decisions = const ImportDecisions(),
    this.preparation,
    this.busy = false,
    this.error,
    this.committed,
    this.saveProfileName = '',
    this.updateProfile = false,
  });

  final ImportStep step;
  final List<LoadedSource> sources;
  final ImportConfig config;
  final String? profileId;
  final String? profileName;

  /// [SheetConfig.key] shown in the structure/mapping/formats steps.
  final String? selectedSheet;
  final ImportContext? context;
  final ImportAnalysis? analysis;

  /// The config [analysis] was computed for.
  final ImportConfig? analysedConfig;
  final ImportDecisions decisions;
  final ImportPreparation? preparation;
  final bool busy;
  final Object? error;
  final ImportCommitResult? committed;
  final String saveProfileName;
  final bool updateProfile;

  List<RawWorkbook> get workbooks => [for (final s in sources) ?s.workbook];

  bool get analysisFresh =>
      analysis != null && identical(analysedConfig, config);

  /// (workbook, sheet, config) of every sheet in file order.
  List<(RawWorkbook, RawSheet, SheetConfig)> get allSheets => [
    for (final wb in workbooks)
      for (final sh in wb.sheets)
        if (config.sheet(sheetKey(wb.fileName, sh.name)) case final cfg?)
          (wb, sh, cfg),
  ];

  List<(RawWorkbook, RawSheet, SheetConfig)> get includedSheets => [
    for (final s in allSheets)
      if (s.$3.include) s,
  ];

  (RawWorkbook, RawSheet, SheetConfig)? get currentSheet {
    final included = includedSheets;
    if (included.isEmpty) return null;
    return included.firstWhereOrNull((s) => s.$3.key == selectedSheet) ??
        included.first;
  }

  ImportWizardState copyWith({
    ImportStep? step,
    List<LoadedSource>? sources,
    ImportConfig? config,
    Object? profileId = _unset,
    Object? profileName = _unset,
    Object? selectedSheet = _unset,
    Object? context = _unset,
    Object? analysis = _unset,
    Object? analysedConfig = _unset,
    ImportDecisions? decisions,
    Object? preparation = _unset,
    bool? busy,
    Object? error = _unset,
    Object? committed = _unset,
    String? saveProfileName,
    bool? updateProfile,
  }) => ImportWizardState(
    step: step ?? this.step,
    sources: sources ?? this.sources,
    config: config ?? this.config,
    profileId: profileId == _unset ? this.profileId : profileId as String?,
    profileName: profileName == _unset
        ? this.profileName
        : profileName as String?,
    selectedSheet: selectedSheet == _unset
        ? this.selectedSheet
        : selectedSheet as String?,
    context: context == _unset ? this.context : context as ImportContext?,
    analysis: analysis == _unset ? this.analysis : analysis as ImportAnalysis?,
    analysedConfig: analysedConfig == _unset
        ? this.analysedConfig
        : analysedConfig as ImportConfig?,
    decisions: decisions ?? this.decisions,
    preparation: preparation == _unset
        ? this.preparation
        : preparation as ImportPreparation?,
    busy: busy ?? this.busy,
    error: error == _unset ? this.error : error,
    committed: committed == _unset
        ? this.committed
        : committed as ImportCommitResult?,
    saveProfileName: saveProfileName ?? this.saveProfileName,
    updateProfile: updateProfile ?? this.updateProfile,
  );
}

const _unset = Object();

final importWizardProvider =
    NotifierProvider.autoDispose<ImportWizardController, ImportWizardState>(
      ImportWizardController.new,
    );

/// Preview of the current sheet (parsed synchronously; cheap enough for
/// the visible sheet).
final currentSheetPreviewProvider = Provider.autoDispose<ParsedSheet?>((ref) {
  final s = ref.watch(importWizardProvider);
  final cur = s.currentSheet;
  if (cur == null) return null;
  return parseSheet(cur.$1, cur.$2, cur.$3, s.config.filters);
});

/// Planned transactions with duplicate status, without rules (duplicates
/// step).
final plannedDraftsProvider = Provider.autoDispose<ImportDraftSet?>((ref) {
  final s = ref.watch(importWizardProvider);
  final a = s.analysis;
  final ctx = s.context;
  if (a == null || ctx == null) return null;
  return buildImportDrafts(a, s.config, ctx, decisions: s.decisions);
});

class ImportWizardController extends Notifier<ImportWizardState> {
  int _generation = 0;

  @override
  ImportWizardState build() => const ImportWizardState();

  ImportService get _service => ref.read(importServiceProvider);

  // -------------------------------------------------------------- source --

  Future<void> addFiles(List<(String, Uint8List)> files) async {
    if (files.isEmpty) return;
    state = state.copyWith(busy: true, error: null);
    final added = <LoadedSource>[];
    for (final (name, bytes) in files) {
      final source = ImportSource.file(_uniqueName(name, added), bytes);
      added.add(await _read(source, state.config.csvOptions[source.name]));
    }
    await _setSources([...state.sources, ...added]);
  }

  Future<void> addPaste(String text) async {
    if (text.trim().isEmpty) return;
    state = state.copyWith(busy: true, error: null);
    final n = state.sources.where((s) => s.source.text != null).length;
    final source = ImportSource.paste(
      text,
      name: n == 0 ? 'Clipboard' : 'Clipboard ${n + 1}',
    );
    await _setSources([...state.sources, await _read(source, null)]);
  }

  Future<void> removeSource(int index) async {
    final next = [...state.sources]..removeAt(index);
    await _setSources(next);
  }

  /// Re-reads a CSV file with other encoding/delimiter/quote.
  Future<void> setCsvOptions(int index, CsvReadOptions options) async {
    final src = state.sources[index];
    state = state.copyWith(busy: true);
    final reread = await _read(src.source, options);
    final next = [...state.sources]..[index] = reread;
    final csv = {...state.config.csvOptions, src.source.name: options};
    state = state.copyWith(config: state.config.copyWith(csvOptions: csv));
    await _setSources(next);
  }

  String _uniqueName(String name, List<LoadedSource> pending) {
    final taken = {
      for (final s in [...state.sources, ...pending]) s.source.name,
    };
    if (!taken.contains(name)) return name;
    var i = 2;
    while (taken.contains('$name ($i)')) {
      i++;
    }
    return '$name ($i)';
  }

  Future<LoadedSource> _read(ImportSource source, CsvReadOptions? csv) async {
    final options = csv ?? const CsvReadOptions();
    try {
      final wb = await _service.read(source, csv: options);
      return LoadedSource(source: source, workbook: wb, csv: options);
    } on ImportReadException catch (e) {
      return LoadedSource(source: source, error: e, csv: options);
    }
  }

  Future<void> _setSources(List<LoadedSource> sources) async {
    state = state.copyWith(sources: sources, busy: true);
    await _reinitConfig();
  }

  Future<void> _reinitConfig() async {
    final gen = ++_generation;
    final wbs = state.workbooks;
    ImportConfig? profile;
    if (state.profileId != null) {
      final p = await ref
          .read(importProfileRepositoryProvider)
          .byId(state.profileId!);
      if (p != null) profile = ImportProfileRepository.configOf(p);
    }
    final ctx = await _service.loadContext(wbs, profileId: state.profileId);
    if (gen != _generation) return;
    final fields = [for (final f in ctx.customFields) (f.id, f.name)];
    final base = profile ?? state.config;
    var cfg = initialConfig(wbs, profile: profile, customFields: fields);
    cfg = cfg.copyWith(
      csvOptions: {...base.csvOptions, ...state.config.csvOptions},
    );
    if (profile == null) {
      // Keep choices made for sheets that are still there.
      cfg = cfg.copyWith(
        sheets: [for (final s in cfg.sheets) state.config.sheet(s.key) ?? s],
        accounts: state.config.accounts,
        categories: state.config.categories,
        filters: state.config.filters,
        transfers: state.config.transfers,
        duplicates: state.config.duplicates,
        incremental: state.config.incremental,
        applyRules: state.config.applyRules,
        setOpeningBalances: state.config.setOpeningBalances,
      );
    }
    state = state.copyWith(
      config: cfg,
      context: ctx,
      analysis: null,
      analysedConfig: null,
      preparation: null,
      busy: false,
    );
  }

  /// Selects a saved profile (null = none) and re-applies it.
  Future<void> useProfile(String? id) async {
    String? name;
    if (id != null) {
      name = (await ref.read(importProfileRepositoryProvider).byId(id))?.name;
    }
    state = state.copyWith(
      profileId: id,
      profileName: name,
      busy: true,
      updateProfile: id != null,
      config: const ImportConfig(),
    );
    await _reinitConfig();
  }

  /// Imports a profile JSON file and selects it.
  Future<bool> importProfileFile(String json) async {
    try {
      final id = await ref
          .read(importProfileRepositoryProvider)
          .importJson(json);
      await useProfile(id);
      return true;
    } on FormatException {
      return false;
    }
  }

  // -------------------------------------------------------------- config --

  void selectSheet(String key) => state = state.copyWith(selectedSheet: key);

  void updateSheet(SheetConfig sheet) =>
      _setConfig(state.config.withSheet(sheet));

  void updateConfig(ImportConfig config) => _setConfig(config);

  /// Copies the column mapping of [source] to every other sheet with the
  /// same header labels. Returns how many sheets changed.
  int applyMappingToSimilar(SheetConfig source) {
    final sig = source.headerSignature.where((h) => h.isNotEmpty).toList();
    var n = 0;
    final sheets = <SheetConfig>[
      for (final s in state.config.sheets)
        if (s.key != source.key &&
            sig.isNotEmpty &&
            const ListEquality<String>().equals(
              s.headerSignature.where((h) => h.isNotEmpty).toList(),
              sig,
            ))
          () {
            n++;
            return s.copyWith(
              columns: source.columns,
              amountMode: source.amountMode,
              invertSign: source.invertSign,
              typeTokens: source.typeTokens,
              categorySeparator: source.categorySeparator,
              tagSeparator: source.tagSeparator,
            );
          }()
        else
          s,
    ];
    if (n > 0) _setConfig(state.config.copyWith(sheets: sheets));
    return n;
  }

  void setAccountTarget(String key, AccountTarget target) {
    _setConfig(
      state.config.copyWith(accounts: {...state.config.accounts, key: target}),
    );
    run(ensureAnalysis);
  }

  void setCategoryTarget(String key, CategoryTarget target) {
    _setConfig(
      state.config.copyWith(
        categories: {...state.config.categories, key: target},
      ),
    );
    run(ensureAnalysis);
  }

  /// Changes transfer detection and re-analyses.
  void setTransferConfig(TransferConfig transfers) {
    _setConfig(state.config.copyWith(transfers: transfers));
    run(ensureAnalysis);
  }

  /// Changes incremental mode and re-analyses.
  void setIncremental({required bool value}) {
    _setConfig(state.config.copyWith(incremental: value));
    run(ensureAnalysis);
  }

  void _setConfig(ImportConfig config) {
    state = state.copyWith(config: config, preparation: null);
  }

  // ----------------------------------------------------------- decisions --

  void setTransfer(String key, {required bool merge}) => state = state.copyWith(
    decisions: state.decisions.copyWith(
      transfers: {...state.decisions.transfers, key: merge},
    ),
    preparation: null,
  );

  void setAllTransfers({required bool merge}) {
    final a = state.analysis;
    if (a == null) return;
    state = state.copyWith(
      decisions: state.decisions.copyWith(
        transfers: {for (final t in a.transfers) t.key: merge},
      ),
      preparation: null,
    );
  }

  void setInclude(String ref, {required bool include}) =>
      state = state.copyWith(
        decisions: state.decisions.copyWith(
          include: {...state.decisions.include, ref: include},
        ),
        preparation: null,
      );

  /// Sets every duplicate row to [include] and remembers it as policy.
  void setAllDuplicates({required bool include}) {
    final set = ref.read(plannedDraftsProvider);
    final next = {...state.decisions.include};
    for (final t in set?.txns ?? const <PlannedTxn>[]) {
      if (t.dup == DupStatus.existing || t.dup == DupStatus.batch) {
        next[t.ref] = include;
      }
    }
    state = state.copyWith(
      decisions: state.decisions.copyWith(include: next),
      config: state.config.copyWith(
        duplicates: include ? DuplicatePolicy.import : DuplicatePolicy.skip,
      ),
      preparation: null,
    );
  }

  void setSaveProfileName(String name) =>
      state = state.copyWith(saveProfileName: name);

  void setUpdateProfile({required bool value}) =>
      state = state.copyWith(updateProfile: value);

  // ---------------------------------------------------------- navigation --

  bool canLeave(ImportStep step) {
    switch (step) {
      case ImportStep.source:
        return state.workbooks.isNotEmpty && !state.busy;
      case ImportStep.sheets:
        return state.includedSheets.isNotEmpty;
      case ImportStep.structure:
      case ImportStep.mapping:
      case ImportStep.formats:
        return state.includedSheets.every((s) {
          final c = s.$3;
          final hasDate = c.columnFor(ColumnTarget.date) != null;
          final hasAmount = switch (c.amountMode) {
            AmountMode.signed || AmountMode.amountWithType =>
              c.columnFor(ColumnTarget.amount) != null,
            AmountMode.debitCredit =>
              c.columnFor(ColumnTarget.debit) != null ||
                  c.columnFor(ColumnTarget.credit) != null,
          };
          return hasDate && hasAmount;
        });
      case ImportStep.categories:
      case ImportStep.transfers:
      case ImportStep.duplicates:
        return state.analysis != null && !state.busy;
      case ImportStep.summary:
        return false;
    }
  }

  Future<void> goTo(ImportStep step) async {
    state = state.copyWith(step: step, error: null);
    if (step.index >= ImportStep.categories.index) await ensureAnalysis();
    if (step == ImportStep.summary) await ensurePreparation();
  }

  Future<void> next() async {
    final i = state.step.index;
    if (i + 1 < ImportStep.values.length) {
      await goTo(ImportStep.values[i + 1]);
    }
  }

  Future<void> back() async {
    final i = state.step.index;
    if (i > 0) await goTo(ImportStep.values[i - 1]);
  }

  /// (Re)computes the analysis in the background when the config changed.
  Future<void> ensureAnalysis() async {
    if (state.analysisFresh) return;
    final ctx = state.context;
    if (ctx == null) return;
    final gen = ++_generation;
    final config = state.config;
    state = state.copyWith(busy: true);
    try {
      final a = await _service.analyse(state.workbooks, config, ctx);
      if (gen != _generation) return;
      state = state.copyWith(
        analysis: a,
        analysedConfig: config,
        busy: false,
        preparation: null,
      );
    } on Object catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(busy: false, error: e);
    }
  }

  Future<void> ensurePreparation() async {
    await ensureAnalysis();
    final a = state.analysis;
    final ctx = state.context;
    if (a == null || ctx == null || state.preparation != null) return;
    state = state.copyWith(busy: true);
    try {
      final p = await _service.prepare(
        a,
        state.config,
        ctx,
        decisions: state.decisions,
      );
      state = state.copyWith(preparation: p, busy: false);
    } on Object catch (e) {
      state = state.copyWith(busy: false, error: e);
    }
  }

  /// Re-runs the summary after toggling summary options.
  Future<void> setSummaryOptions({bool? applyRules, bool? setOpening}) async {
    state = state.copyWith(
      config: state.config.copyWith(
        applyRules: applyRules,
        setOpeningBalances: setOpening,
      ),
      preparation: null,
    );
    await ensurePreparation();
  }

  /// Writes the import. Returns the result, or null on failure (see
  /// [ImportWizardState.error]).
  Future<ImportCommitResult?> commit() async {
    await ensurePreparation();
    final prep = state.preparation;
    if (prep == null) return null;
    state = state.copyWith(busy: true, error: null);
    try {
      final result = await _service.commit(
        prep,
        workbooks: state.workbooks,
        config: state.config,
        profileId: state.profileId,
        saveProfileAs: state.profileId == null || !state.updateProfile
            ? state.saveProfileName
            : null,
        updateProfile: state.updateProfile,
      );
      state = state.copyWith(busy: false, committed: result);
      return result;
    } on Object catch (e) {
      state = state.copyWith(busy: false, error: e);
      return null;
    }
  }

  /// Undoes the batch just written.
  Future<void> undoCommitted() async {
    final c = state.committed;
    if (c == null) return;
    state = state.copyWith(busy: true);
    try {
      await withSafetyCopy(
        ref.read,
        SafetyReason.importUndo,
        () => ref.read(importRepositoryProvider).undo(c.batchId),
      );
    } on SafetyCopyException catch (e) {
      state = state.copyWith(busy: false, error: e);
      return;
    }
    state = state.copyWith(busy: false, committed: null, preparation: null);
    await _reinitConfigKeepingChoices();
  }

  Future<void> _reinitConfigKeepingChoices() async {
    final ctx = await _service.loadContext(
      state.workbooks,
      profileId: state.profileId,
    );
    state = state.copyWith(context: ctx, analysis: null, analysedConfig: null);
  }

  /// Starts over.
  void reset() {
    _generation++;
    state = const ImportWizardState();
  }

  /// Fire-and-forget helper for UI callbacks.
  void run(Future<void> Function() f) => unawaited(f());
}
