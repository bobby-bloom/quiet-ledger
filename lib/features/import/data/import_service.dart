import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/features/import/data/import_repository.dart';
import 'package:personal_finance/features/import/data/profile_repository.dart';
import 'package:personal_finance/features/import/domain/background.dart';
import 'package:personal_finance/features/import/domain/import_analysis.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/import_drafts.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/source_reader.dart';
import 'package:personal_finance/features/rules/domain/rule_service.dart';

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(
    ref.watch(importRepositoryProvider),
    ref.watch(importProfileRepositoryProvider),
    ref.watch(ruleServiceProvider),
  ),
);

/// A file (bytes) or a clipboard paste (text) to import.
@immutable
class ImportSource {
  const ImportSource.file(this.name, Uint8List this.bytes) : text = null;

  const ImportSource.paste(String this.text, {this.name = 'Clipboard'})
    : bytes = null;

  final String name;
  final Uint8List? bytes;
  final String? text;
}

/// Everything the summary step shows and the commit writes.
@immutable
class ImportPreparation {
  const ImportPreparation({
    required this.context,
    required this.analysis,
    required this.drafts,
    required this.summary,
    required this.categorisedByRules,
  });

  final ImportContext context;
  final ImportAnalysis analysis;

  /// After rules.
  final ImportDraftSet drafts;
  final ImportSummary summary;
  final int categorisedByRules;
}

/// Orchestrates the import pipeline: reading and analysing run in a
/// background isolate (plain async on the web), rules and the commit on
/// the main isolate.
class ImportService {
  ImportService(this.repository, this.profiles, this.rules);

  final ImportRepository repository;
  final ImportProfileRepository profiles;
  final RuleService rules;

  /// Reads one source. Throws [ImportReadException].
  Future<RawWorkbook> read(
    ImportSource source, {
    CsvReadOptions csv = const CsvReadOptions(),
  }) {
    final bytes = source.bytes;
    final text = source.text;
    final name = source.name;
    if (bytes != null) {
      return runInBackground(
        () => readImportFile(bytes, fileName: name, csv: csv),
      );
    }
    return runInBackground(() => readClipboardText(text!, name: name));
  }

  Future<ImportContext> loadContext(
    List<RawWorkbook> workbooks, {
    String? profileId,
  }) => repository.loadContext(
    profileId: profileId,
    files: [
      for (final w in workbooks)
        ImportFileInfo(name: w.fileName, hash: w.fileHash, rows: 0),
    ],
  );

  Future<ImportAnalysis> analyse(
    List<RawWorkbook> workbooks,
    ImportConfig config,
    ImportContext context,
  ) => runInBackground(() => analyseImport(workbooks, config, context));

  /// Builds the drafts, applies rules (when [ImportConfig.applyRules]) to
  /// included rows without a category and summarises.
  Future<ImportPreparation> prepare(
    ImportAnalysis analysis,
    ImportConfig config,
    ImportContext context, {
    ImportDecisions decisions = const ImportDecisions(),
  }) async {
    var set = buildImportDrafts(
      analysis,
      config,
      context,
      decisions: decisions,
    );
    var categorised = 0;
    if (config.applyRules) {
      final idx = <int>[
        for (var i = 0; i < set.txns.length; i++)
          if (set.txns[i].included &&
              !set.txns[i].draft.isTransfer &&
              set.txns[i].draft.categoryId == null)
            i,
      ];
      if (idx.isNotEmpty) {
        final out = await rules.applyAll([
          for (final i in idx) set.txns[i].draft,
        ], trigger: RuleTrigger.import);
        final txns = [...set.txns];
        for (var k = 0; k < idx.length; k++) {
          final before = txns[idx[k]];
          if (out[k].categoryId != null) categorised++;
          txns[idx[k]] = before.copyWith(draft: out[k]);
        }
        set = set.withTxns(txns);
      }
    }
    return ImportPreparation(
      context: context,
      analysis: analysis,
      drafts: set,
      summary: summariseImport(
        set,
        analysis,
        context,
        categorisedByRules: categorised,
      ),
      categorisedByRules: categorised,
    );
  }

  /// Writes the prepared import. With [saveProfileAs] the config is saved
  /// as a new profile (or [profileId] is updated when [updateProfile]) in
  /// the same DB transaction.
  Future<ImportCommitResult> commit(
    ImportPreparation prep, {
    required List<RawWorkbook> workbooks,
    required ImportConfig config,
    String? profileId,
    String? saveProfileAs,
    bool updateProfile = false,
  }) {
    // The profile remembers the effective account/category choices.
    final effective = config.copyWith(
      accounts: {...prep.analysis.accountTargets},
      categories: {...prep.analysis.categoryTargets},
    );
    return repository.writer.transaction(() async {
      var pid = profileId;
      if (saveProfileAs != null && saveProfileAs.trim().isNotEmpty) {
        pid = await profiles.save(name: saveProfileAs, config: effective);
      } else if (updateProfile && pid != null) {
        final existing = await profiles.byId(pid);
        if (existing != null) {
          await profiles.save(name: existing.name, config: effective, id: pid);
        }
      }
      return await repository.commit(
        set: prep.drafts,
        files: [
          for (final w in workbooks)
            ImportFileInfo(name: w.fileName, hash: w.fileHash, rows: 0),
        ],
        summary: prep.summary.toJson(),
        profileId: pid,
      );
    });
  }
}
