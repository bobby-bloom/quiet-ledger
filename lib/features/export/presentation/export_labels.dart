import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/core/settings/app_settings.dart';
import 'package:personal_finance/core/settings/setting_def.dart';
import 'package:personal_finance/features/export/domain/bundle_manifest.dart';
import 'package:personal_finance/features/export/domain/txn_export.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

/// Localized texts of the transaction CSV.
TxnExportLabels txnExportLabels(AppLocalizations l) => TxnExportLabels(
  headers: {
    TxnColumnKeys.date: l.exportColDate,
    TxnColumnKeys.valueDate: l.exportColValueDate,
    TxnColumnKeys.account: l.exportColAccount,
    TxnColumnKeys.type: l.exportColType,
    TxnColumnKeys.amount: l.exportColAmount,
    TxnColumnKeys.currency: l.exportColCurrency,
    TxnColumnKeys.payee: l.exportColPayee,
    TxnColumnKeys.note: l.exportColNote,
    TxnColumnKeys.category: l.exportColCategory,
    TxnColumnKeys.split: l.exportColSplit,
    TxnColumnKeys.tags: l.exportColTags,
    TxnColumnKeys.status: l.exportColStatus,
    TxnColumnKeys.transferAccount: l.exportColTransferAccount,
    TxnColumnKeys.id: l.exportColId,
  },
  types: {
    TxnType.expense: l.typeExpense,
    TxnType.income: l.typeIncome,
    TxnType.transfer: l.typeTransfer,
  },
  statuses: {
    TxnStatus.cleared: l.statusCleared,
    TxnStatus.pending: l.statusPending,
    TxnStatus.planned: l.statusPlanned,
  },
);

/// Label of a choice value as defined by the settings catalogue.
String choiceLabel(AppLocalizations l, SettingDef<Object?> def, String value) =>
    switch (def.editor) {
      ChoiceEditor(:final labels) => labels(l, value),
      _ => value,
    };

String delimiterLabel(AppLocalizations l, CsvDelimiter v) =>
    choiceLabel(l, ImportExportSettings.csvDelimiter, v.name);

String encodingLabel(AppLocalizations l, CsvEncoding v) =>
    choiceLabel(l, ImportExportSettings.csvEncoding, v.name);

String decimalLabel(AppLocalizations l, DecimalSeparator v) =>
    choiceLabel(l, ImportExportSettings.csvDecimalSeparator, v.name);

String scheduleLabel(AppLocalizations l, AutoExportSchedule v) =>
    choiceLabel(l, ImportExportSettings.autoExport, v.name);

/// Date format choices offered for CSV files.
List<String> csvDateFormats() =>
    switch (ImportExportSettings.csvDateFormat.editor) {
      ChoiceEditor(:final values) => values,
      _ => const ['yyyy-MM-dd'],
    };

/// User-facing message for a bundle error.
String bundleErrorMessage(AppLocalizations l, BundleException e) =>
    switch (e.kind) {
      BundleErrorKind.notABundle => l.exportErrNotBundle,
      BundleErrorKind.newerFormat ||
      BundleErrorKind.newerSchema => l.exportErrNewerFormat,
      BundleErrorKind.checksumMismatch => l.exportErrChecksum(e.detail),
      BundleErrorKind.invalidContent => l.exportErrInvalid(e.detail),
    };
