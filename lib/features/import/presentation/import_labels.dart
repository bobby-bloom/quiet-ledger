import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/features/import/domain/date_parser.dart';
import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/import_drafts.dart';
import 'package:personal_finance/features/import/domain/number_parser.dart';
import 'package:personal_finance/features/import/domain/raw_sheet.dart';
import 'package:personal_finance/features/import/domain/row_parser.dart';
import 'package:personal_finance/features/import/presentation/import_wizard_controller.dart';
import 'package:personal_finance/l10n/generated/app_localizations.dart';

// Enum → user-visible label.

extension ImportLabels on AppLocalizations {
  String importStepLabel(ImportStep s) => switch (s) {
    ImportStep.source => importStepSource,
    ImportStep.sheets => importStepSheets,
    ImportStep.structure => importStepStructure,
    ImportStep.mapping => importStepMapping,
    ImportStep.formats => importStepFormats,
    ImportStep.categories => importStepValues,
    ImportStep.transfers => importStepTransfers,
    ImportStep.duplicates => importStepDuplicates,
    ImportStep.summary => importStepSummary,
  };

  String importTargetLabel(
    ColumnTarget t, {
    String separator = '',
    String? fieldName,
    AmountMode mode = AmountMode.signed,
  }) => switch (t) {
    ColumnTarget.ignore => importTargetIgnore,
    ColumnTarget.date => importTargetDate,
    ColumnTarget.valueDate => importTargetValueDate,
    ColumnTarget.amount =>
      mode == AmountMode.amountWithType
          ? importTargetAmountAbs
          : importTargetAmount,
    ColumnTarget.debit => importTargetDebit,
    ColumnTarget.credit => importTargetCredit,
    ColumnTarget.amountType => importTargetAmountType,
    ColumnTarget.payee => importTargetPayee,
    ColumnTarget.note => importTargetNote,
    ColumnTarget.category =>
      separator.isEmpty
          ? importTargetCategory
          : importTargetCategorySub(separator.trim()),
    ColumnTarget.subcategory => importTargetSubcategory,
    ColumnTarget.account => importTargetAccount,
    ColumnTarget.tags => importTargetTags,
    ColumnTarget.status => importTargetStatus,
    ColumnTarget.customField => importTargetCustom(fieldName ?? '?'),
    ColumnTarget.balance => importTargetBalance,
  };

  String importDateFormatLabel(DateFormatKind k) => switch (k) {
    DateFormatKind.auto => importAuto,
    DateFormatKind.excelSerial => importDateSerial,
    DateFormatKind.dmy => importDateDmy,
    DateFormatKind.mdy => importDateMdy,
    DateFormatKind.ymd => importDateYmd,
    DateFormatKind.compact => importDateCompact,
    DateFormatKind.monthName => importDateMonthName,
  };

  String importNumberFormatLabel(NumberFormatKind k) => switch (k) {
    NumberFormatKind.auto => importAuto,
    NumberFormatKind.de => importNumberDe,
    NumberFormatKind.en => importNumberEn,
    NumberFormatKind.space => importNumberSpace,
  };

  String importEncodingLabel(TextEncoding e) => switch (e) {
    TextEncoding.auto => importAuto,
    TextEncoding.utf8 => 'UTF-8',
    TextEncoding.utf16le => 'UTF-16 LE',
    TextEncoding.utf16be => 'UTF-16 BE',
    TextEncoding.windows1252 => 'Windows-1252',
    TextEncoding.latin1 => 'ISO-8859-1',
    TextEncoding.latin9 => 'ISO-8859-15',
  };

  String importDelimiterLabel(String d) => switch (d) {
    '\t' => importTab,
    ' ' => importSeparatorSpace,
    '' => importSeparatorNone,
    _ => d,
  };

  String importRowClassLabel(RowClass c) => switch (c) {
    RowClass.data => importRowData,
    RowClass.title => importRowTitle,
    RowClass.header => importRowHeader,
    RowClass.empty => importRowEmpty,
    RowClass.subtotal => importRowSubtotal,
    RowClass.noDate => importRowNoDate,
    RowClass.noAmount => importRowNoAmount,
    RowClass.afterEnd => importRowAfterEnd,
    RowClass.invalid => importRowInvalid,
  };

  String importIssueLabel(IssueKind k) => switch (k) {
    IssueKind.badDate => importIssueBadDate,
    IssueKind.missingDate => importIssueMissingDate,
    IssueKind.badValueDate => importIssueBadValueDate,
    IssueKind.badAmount => importIssueBadAmount,
    IssueKind.missingAmount => importIssueMissingAmount,
    IssueKind.badType => importIssueBadType,
    IssueKind.badBalance => importIssueBadBalance,
    IssueKind.badStatus => importIssueBadStatus,
    IssueKind.badCustomField => importIssueBadCustomField,
    IssueKind.missingAccount => importIssueMissingAccount,
    IssueKind.yearMismatch => importIssueYearMismatch,
  };

  String importReadErrorLabel(ImportReadError e) => switch (e) {
    ImportReadError.ods => importErrOds,
    ImportReadError.numbers => importErrNumbers,
    ImportReadError.encrypted => importErrEncrypted,
    ImportReadError.notASpreadsheet => importErrNotSpreadsheet,
    ImportReadError.corrupt => importErrCorrupt,
    ImportReadError.empty => importErrEmpty,
  };

  String importAccountTypeLabel(AccountType t) => switch (t) {
    AccountType.checking => importAccTypeChecking,
    AccountType.savings => importAccTypeSavings,
    AccountType.cash => importAccTypeCash,
    AccountType.creditCard => importAccTypeCreditCard,
    AccountType.investment => importAccTypeInvestment,
    AccountType.loan => importAccTypeLoan,
    AccountType.otherAsset => importAccTypeOtherAsset,
    AccountType.otherLiability => importAccTypeOtherLiability,
  };

  String importWarningLabel(ImportWarning w) => switch (w.kind) {
    ImportWarningKind.invalidRows => importWarnInvalid(w.count),
    ImportWarningKind.balanceMismatch => importWarnMismatch(w.count, w.subject),
    ImportWarningKind.formulasWithoutValue => importWarnFormulas(w.count),
    ImportWarningKind.yearMismatch => importWarnYear(w.count),
    ImportWarningKind.uncategorised => importWarnUncategorised(w.count),
    ImportWarningKind.duplicatesIncluded => importWarnDuplicates(w.count),
  };
}

/// Compact "5, 7, 12 …" list of 1-based row numbers.
String rowList(Iterable<int> zeroBasedRows, {int max = 6}) {
  final rows = zeroBasedRows.map((r) => r + 1).toSet().toList()..sort();
  final shown = rows.take(max).join(', ');
  return rows.length > max ? '$shown …' : shown;
}
