// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get accountsAdd => 'Add account';

  @override
  String get accountsEmpty =>
      'No accounts yet. Add your bank accounts, cash and cards to track balances and net worth.';

  @override
  String get accountsReorder => 'Reorder accounts';

  @override
  String get accountsReorderHint =>
      'Drag accounts to change their order, or below another heading to move them into that group.';

  @override
  String accountsDragHandle(String name) {
    return 'Move $name';
  }

  @override
  String get accountsReconcileBalances => 'Reconcile balances';

  @override
  String get accountsSelectHint => 'Select an account to see its details.';

  @override
  String get accountsMoreActions => 'More actions';

  @override
  String get accountsManageGroups => 'Manage groups';

  @override
  String get accountsShowArchivedMenu => 'Show archived accounts';

  @override
  String get accountsHideArchived => 'Hide archived accounts';

  @override
  String accountsShowArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count archived accounts',
      one: 'Show 1 archived account',
    );
    return '$_temp0';
  }

  @override
  String get accountsArchivedSection => 'Archived';

  @override
  String get accountsArchivedDesc =>
      'Hidden from lists and pickers. Its history stays.';

  @override
  String get accountsNetWorth => 'Net worth';

  @override
  String get accountsAssets => 'Assets';

  @override
  String get accountsLiabilities => 'Liabilities';

  @override
  String accountsNetWorthSemantics(
    String net,
    String assets,
    String liabilities,
  ) {
    return 'Net worth $net. Assets $assets, liabilities $liabilities.';
  }

  @override
  String accountsAlertBelow(String amount) {
    return 'Alert below $amount';
  }

  @override
  String accountsBelowThreshold(String amount) {
    return 'Below the $amount alert';
  }

  @override
  String get accountsNotInNetWorth => 'Not in net worth';

  @override
  String get accountsNotInBudgets => 'Not in budgets';

  @override
  String get accountsNotInForecast => 'Not in forecast';

  @override
  String accountsReturnAssumed(String rate) {
    return '$rate p.a. assumed';
  }

  @override
  String accountsInterestRate(String rate) {
    return '$rate interest';
  }

  @override
  String get accountsOpen => 'Open';

  @override
  String get accountsReconcile => 'Reconcile';

  @override
  String get accountsArchive => 'Archive';

  @override
  String get accountsUnarchive => 'Unarchive';

  @override
  String get accountsNoGroup => 'No group';

  @override
  String get accountsTypeChecking => 'Checking';

  @override
  String get accountsTypeSavings => 'Savings';

  @override
  String get accountsTypeCash => 'Cash';

  @override
  String get accountsTypeCreditCard => 'Credit card';

  @override
  String get accountsTypeInvestment => 'Investment';

  @override
  String get accountsTypeLoan => 'Loan';

  @override
  String get accountsTypeOtherAsset => 'Other asset';

  @override
  String get accountsTypeOtherLiability => 'Other liability';

  @override
  String get accountsArchivedSnack => 'Account archived';

  @override
  String get accountsUnarchivedSnack => 'Account restored';

  @override
  String get accountsCannotDeleteTitle => 'Account in use';

  @override
  String accountsDeleteInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This account has $count transactions and can\'t be deleted. Archive it to hide it while keeping its history.',
      one: 'This account has 1 transaction and can\'t be deleted. Archive it to hide it while keeping its history.',
    );
    return '$_temp0';
  }

  @override
  String accountsDeleteInUseRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count recurring rules use this account. Change or delete them first, or archive the account.',
      one: 'A recurring rule uses this account. Change or delete it first, or archive the account.',
    );
    return '$_temp0';
  }

  @override
  String get accountsDeleteMessage =>
      'The account has no transactions. Linked goals are unlinked.';

  @override
  String get accountsDeleted => 'Account deleted';

  @override
  String get accountsNotFound => 'This account no longer exists.';

  @override
  String get accountsRange1M => '1M';

  @override
  String get accountsRange3M => '3M';

  @override
  String get accountsRange6M => '6M';

  @override
  String get accountsRange1Y => '1Y';

  @override
  String get accountsRangeAll => 'All';

  @override
  String get accountsCurrentBalance => 'Current balance';

  @override
  String accountsLowBalanceWarning(String amount) {
    return 'Below the low-balance alert of $amount';
  }

  @override
  String get accountsBalanceOverTime => 'Balance over time';

  @override
  String get accountsChartEmpty => 'Not enough data for a chart yet.';

  @override
  String accountsChartSemantics(
    String name,
    String from,
    String to,
    String start,
    String end,
    String lowest,
  ) {
    return 'Balance of $name from $from to $to: $start at the start, $end at the end, lowest $lowest.';
  }

  @override
  String get accountsRecentTransactions => 'Recent transactions';

  @override
  String get accountsAllTransactions => 'All';

  @override
  String get accountsNoTransactions => 'No transactions in this account yet.';

  @override
  String get accountsDetails => 'Details';

  @override
  String accountsTransferWith(String name) {
    return 'Transfer · $name';
  }

  @override
  String get accountsSplit => 'Split';

  @override
  String get accountsUncategorized => 'Uncategorised';

  @override
  String get accountsNew => 'New account';

  @override
  String get accountsEditTitle => 'Edit account';

  @override
  String get accountsCreate => 'Create account';

  @override
  String get accountsSectionBasics => 'Basics';

  @override
  String get accountsSectionAppearance => 'Appearance';

  @override
  String get accountsSectionInclude => 'Counts toward';

  @override
  String get accountsSectionPlanning => 'Planning';

  @override
  String get accountsFieldName => 'Name';

  @override
  String get accountsNameRequired => 'Enter a name';

  @override
  String get accountsFieldType => 'Type';

  @override
  String get accountsFieldOpeningBalance => 'Opening balance';

  @override
  String get accountsFieldOpeningDate => 'Opening date';

  @override
  String get accountsLiabilityHint =>
      'Enter debt as a negative amount, e.g. −4,152.30.';

  @override
  String get accountsFieldGroup => 'Group';

  @override
  String get accountsNewGroup => 'New group…';

  @override
  String get accountsGroupName => 'Group name';

  @override
  String get accountsIncludeNetWorth => 'Net worth';

  @override
  String get accountsIncludeBudgets => 'Budgets';

  @override
  String get accountsIncludeBudgetsDesc =>
      'Spending from this account counts against budgets';

  @override
  String get accountsIncludeForecast => 'Forecast';

  @override
  String get accountsLowBalance => 'Low-balance alert';

  @override
  String get accountsLowBalanceHint =>
      'Warn when the balance falls below this amount';

  @override
  String get accountsExpectedReturn => 'Expected annual return';

  @override
  String get accountsExpectedReturnHint => 'Used by the net-worth projection';

  @override
  String get accountsInterest => 'Interest rate';

  @override
  String get accountsInterestHint =>
      'Annual rate, e.g. for loans and credit cards';

  @override
  String get accountsRateInvalid => 'Enter a percentage between −100 and 100';

  @override
  String get accountsNote => 'Note';

  @override
  String get accountsDiscardTitle => 'Discard changes?';

  @override
  String get accountsKeepEditing => 'Keep editing';

  @override
  String get accountsDiscard => 'Discard';

  @override
  String get accountsReconcileTitle => 'Reconcile';

  @override
  String get accountsReconcileIntro =>
      'Enter the balance your bank shows for the date below. The cleared transactions in the app should add up to it.';

  @override
  String get accountsBankBalance => 'Bank balance';

  @override
  String get accountsBankDate => 'Balance date';

  @override
  String get accountsDifference => 'Difference';

  @override
  String get accountsClearedBalance => 'Cleared in the app';

  @override
  String accountsPendingSum(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pending ($count)',
      one: 'Pending (1)',
      zero: 'Pending',
    );
    return '$_temp0';
  }

  @override
  String get accountsEnterBankBalance => 'Enter the bank balance to compare.';

  @override
  String get accountsReconciled => 'Balanced. The app matches your bank.';

  @override
  String get accountsDifferenceMore =>
      'Your bank shows more than the app. Clear pending income or add the missing entries.';

  @override
  String get accountsDifferenceLess =>
      'Your bank shows less than the app. Clear pending expenses the bank already booked.';

  @override
  String accountsCreateCorrection(String amount) {
    return 'Book correction of $amount';
  }

  @override
  String get accountsCreateCorrectionShort => 'Book correction';

  @override
  String get accountsCorrectionConfirmTitle => 'Book a correction?';

  @override
  String accountsCorrectionConfirm(String amount) {
    return 'A cleared transaction of $amount is added so the app matches the bank balance.';
  }

  @override
  String get accountsCorrectionPayee => 'Reconciliation';

  @override
  String get accountsCorrectionNote => 'Correction to match the bank balance';

  @override
  String get accountsCorrectionCreated => 'Correction booked';

  @override
  String get accountsPendingTitle => 'Pending transactions';

  @override
  String get accountsPendingHint =>
      'Select the ones your bank already booked and mark them as cleared.';

  @override
  String get accountsNoPending => 'No pending transactions up to this date.';

  @override
  String get accountsSelectAll => 'Select all';

  @override
  String get accountsMarkClearedNone => 'Mark as cleared';

  @override
  String accountsMarkCleared(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mark $count as cleared ($amount)',
      one: 'Mark 1 as cleared ($amount)',
    );
    return '$_temp0';
  }

  @override
  String accountsMarkedCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions cleared',
      one: '1 transaction cleared',
    );
    return '$_temp0';
  }

  @override
  String get accountsGroupsTitle => 'Account groups';

  @override
  String get accountsGroupsEmpty =>
      'No groups yet. Groups bundle accounts in the list, e.g. \"Daily\" or \"Savings\".';

  @override
  String get accountsGroupsHint =>
      'Tap to rename, drag to reorder. Deleting a group keeps its accounts.';

  @override
  String get accountsGroupAdd => 'Add group';

  @override
  String get accountsGroupRename => 'Rename group';

  @override
  String get accountsGroupDeleteMessage =>
      'Its accounts stay and become ungrouped.';

  @override
  String get accountsGroupDeleted => 'Group deleted';

  @override
  String accountsGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '1 account',
      zero: 'No accounts',
    );
    return '$_temp0';
  }

  @override
  String get backupBootTitle => 'Your data could not be opened';

  @override
  String get backupBootMissingKey =>
      'The key that unlocks the database is missing on this device. This happens when app data is copied to a new device or restored without the device\'s secure storage.';

  @override
  String get backupBootNewer =>
      'The database was created by a newer version of the app. Install the latest version to open it.';

  @override
  String get backupBootGeneric =>
      'The app could not start. This can be temporary, for example when storage is full or the device is still locked. Try again; the database file was not changed.';

  @override
  String get backupBootKept =>
      'Nothing has been deleted. The database file stays on this device.';

  @override
  String get backupBootDetails => 'Technical details';

  @override
  String get backupBootStartFresh => 'Start with an empty database';

  @override
  String get backupBootStartFreshConfirm =>
      'The current database file is moved to a separate folder, not deleted. The app then starts empty, and you can restore a backup under More › Export & backup.';

  @override
  String backupBootMoved(String path) {
    return 'The old database file was moved to:\n$path';
  }

  @override
  String backupMissingReceipts(int count) {
    return 'Backup saved. $count receipt files were already missing on this device and are not in it.';
  }

  @override
  String get backupReceipts => 'Receipts';

  @override
  String backupReceiptsValue(int count, String size) {
    return '$count files, $size';
  }

  @override
  String backupRestoreMissing(int count) {
    return '$count receipt files were already missing when this backup was made and cannot be restored.';
  }

  @override
  String get backupChannel => 'Backups';

  @override
  String get backupHealthBackUp => 'Back up now';

  @override
  String get backupHealthDetails => 'Details';

  @override
  String backupHealthFailing(String message) {
    return 'The automatic backup failed: $message';
  }

  @override
  String get backupHealthInterrupted =>
      'The last automatic backup did not finish.';

  @override
  String get backupHealthNever => 'Your data has not been backed up yet.';

  @override
  String backupHealthStale(String date) {
    return 'Last backup: $date. Back up again so recent changes are safe.';
  }

  @override
  String get backupNotifyFailedTitle => 'Backup failed';

  @override
  String get backupNotifyFailedBody =>
      'Your automatic backup could not be written. Open the app to fix it.';

  @override
  String get backupResetKeepCopy => 'Keep a safety copy on this device';

  @override
  String get backupResetKeepCopyDesc =>
      'Lets you undo the reset under More › Export & backup › Safety copies. Untick to also delete the safety copies.';

  @override
  String get backupSafetyActions => 'Actions';

  @override
  String get backupSafetyDelete => 'Delete';

  @override
  String backupSafetyDeleteConfirm(String date) {
    return 'Delete the safety copy from $date?';
  }

  @override
  String get backupSafetyDesc =>
      'Taken automatically before a restore, a reset, undoing an import, merging categories or tags and removing old deleted entries. They stay on this device and hold all data except receipt files, which these actions never delete. The newest 10 are kept.';

  @override
  String get backupSafetyEmpty => 'No safety copies yet.';

  @override
  String backupSafetyFailed(String message) {
    return 'No safety copy could be taken, so nothing was changed: $message';
  }

  @override
  String get backupSafetyReasonImportUndo => 'Before undoing an import';

  @override
  String get backupSafetyReasonMerge => 'Before merging';

  @override
  String get backupSafetyReasonPurge => 'Before removing old deleted entries';

  @override
  String get backupSafetyReasonReset => 'Before resetting the app';

  @override
  String get backupSafetyReasonRestore => 'Before restoring a backup';

  @override
  String get backupSafetyReasonRestoreCopy => 'Before restoring a safety copy';

  @override
  String get backupSafetyRestore => 'Restore';

  @override
  String backupSafetyRestoreConfirm(String date) {
    return 'Replace all current data with the safety copy from $date? A safety copy of the current data is taken first, so you can go back.';
  }

  @override
  String backupSafetyRestored(int count) {
    return 'Safety copy restored ($count rows)';
  }

  @override
  String backupSafetyRows(String rows, String size) {
    return '$rows rows · $size';
  }

  @override
  String get backupSafetySave => 'Save elsewhere';

  @override
  String get backupSafetyTitle => 'Safety copies';

  @override
  String get backupStaleDays => 'Warn when the last backup is older than';

  @override
  String backupStaleDaysValue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get backupFolderAccessLost =>
      'The app no longer has access to the backup folder. Choose the folder again.';

  @override
  String get backupUseAppDocuments => 'Use “On My iPhone” in Files';

  @override
  String get backupErrDamaged =>
      'The backup file is damaged or was changed. It cannot be restored.';

  @override
  String get backupHealthCheckPassword =>
      'Do you still know your backup password? Type it once to make sure.';

  @override
  String get backupPasswordChange => 'Change password';

  @override
  String get backupPasswordCheck => 'Check password';

  @override
  String get backupPasswordCorrect =>
      'That\'s right. Your backup password is confirmed.';

  @override
  String get backupPasswordDesc =>
      'Backups that leave this device are encrypted with a password you choose. Anyone without the password or the recovery key sees only scrambled data, and so would you: keep both somewhere safe.';

  @override
  String get backupPasswordField => 'Backup password';

  @override
  String get backupPasswordFinish => 'Finish';

  @override
  String get backupPasswordHide => 'Hide password';

  @override
  String backupPasswordLastChecked(String date) {
    return 'Last confirmed on $date';
  }

  @override
  String backupPasswordMinLength(int count) {
    return 'At least $count characters';
  }

  @override
  String get backupPasswordMismatch => 'The passwords do not match';

  @override
  String get backupPasswordNewRecovery => 'New recovery key';

  @override
  String get backupPasswordOn => 'Backups are encrypted';

  @override
  String get backupPasswordRepeat => 'Repeat the password';

  @override
  String get backupPasswordSet => 'Set backup password';

  @override
  String get backupPasswordShow => 'Show password';

  @override
  String backupPasswordSince(String date) {
    return 'Password set on $date';
  }

  @override
  String get backupPasswordStepIntro =>
      'Choose a password for your backups. It is different from the app lock and is needed to restore a backup on another device.';

  @override
  String get backupPasswordTitle => 'Backup password';

  @override
  String get backupPasswordWrong => 'Wrong password';

  @override
  String get backupPasswordWrongDesc =>
      'That is not the backup password. If you no longer know it, set a new one now: new backups use it, and older ones still open with the old password or the recovery key.';

  @override
  String get backupRecoveryConfirmIntro =>
      'To make sure you have the recovery key, type two of its groups.';

  @override
  String get backupRecoveryCopy => 'Copy';

  @override
  String get backupRecoveryFileIntro =>
      'Recovery key for the backups of Quiet Ledger. Anyone with this key can open your backups; keep it private and safe.';

  @override
  String backupRecoveryGroup(int number) {
    return 'Group $number';
  }

  @override
  String get backupRecoveryIntro =>
      'This is your recovery key. It opens your backups if you forget the password. Write it down or save it outside this device, e.g. in a password manager.';

  @override
  String get backupRecoveryKey => 'Recovery key';

  @override
  String get backupRecoverySave => 'Save as file';

  @override
  String get backupRecoveryShowAgain => 'Show the recovery key again';

  @override
  String get backupRecoveryStored =>
      'I have stored the recovery key in a safe place';

  @override
  String get backupRecoveryWarning =>
      'It is shown only now. Without the password and the recovery key, your encrypted backups cannot be opened by anyone.';

  @override
  String get backupUnlockDesc =>
      'This backup is encrypted. Enter its backup password or the recovery key.';

  @override
  String get backupUnlockOpen => 'Open';

  @override
  String get backupUnlockTitle => 'Encrypted backup';

  @override
  String get backupUnlockWrong => 'That does not open this backup. Try again.';

  @override
  String get backupCheck => 'Check a backup';

  @override
  String get backupCheckOk => 'Backup is complete';

  @override
  String backupCheckOkDesc(String file, String date, int rows, int files) {
    return '$file\nMade on $date. All checksums match: $rows rows and $files receipt files can be restored.';
  }

  @override
  String get backupFolderFileGone => 'The backup is no longer in the folder.';

  @override
  String get backupFolderList => 'Backups in the folder';

  @override
  String get backupFolderListEmpty => 'No backups in this folder yet.';

  @override
  String backupRestoreNewer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes on this device are newer than this backup and will be replaced (they stay in the safety copy).',
      one: '1 change on this device is newer than this backup and will be replaced (it stays in the safety copy).',
    );
    return '$_temp0';
  }

  @override
  String get backupWebStorageNotPersistent =>
      'This browser may clear the app\'s data when space runs low. Back up regularly.';

  @override
  String get backupWebStoragePersistent =>
      'This browser keeps the app\'s data and does not clear it on its own.';

  @override
  String get backupBootUnreadable =>
      'The database file is damaged or cannot be unlocked with the key on this device.';

  @override
  String get backupBootCopyDetails => 'Copy details';

  @override
  String get backupAppDocumentsFolder =>
      'On My iPhone › Quiet Ledger › Backups';

  @override
  String get backupFolderMissing =>
      'The backup folder was not found. Connect the drive it is on, or choose the folder again.';

  @override
  String get backupUnencryptedWarning =>
      'Backups are not encrypted. Anyone who gets a backup file can read all your financial data.';

  @override
  String get backupSavedUnencrypted =>
      'Not encrypted: anyone who has the file can read it.';

  @override
  String get boardLabel => 'Layout';

  @override
  String get boardAuto => 'Auto';

  @override
  String get boardCustom => 'Custom';

  @override
  String boardFitsUpTo(int count) {
    return 'This window fits up to $count columns. Your layout shows in full on wider screens.';
  }

  @override
  String get boardFitsOne =>
      'This window fits one column. Your layout shows in full on wider screens.';

  @override
  String boardSplitFits(int count) {
    return 'This window fits up to $count columns';
  }

  @override
  String get boardArrangeNeeds => 'Widen the window to two columns to arrange';

  @override
  String get boardArrangeHint => 'Drag to move';

  @override
  String get boardReset => 'Reset';

  @override
  String boardRow(int row) {
    return 'Row $row';
  }

  @override
  String boardRowOf(int row, int count) {
    return 'Row $row of $count';
  }

  @override
  String boardRowMenu(int row) {
    return 'Row $row options';
  }

  @override
  String get boardNewRow => 'New row';

  @override
  String get boardRowTooWide => 'Needs a wider window';

  @override
  String get boardRowSplit => 'Row layout';

  @override
  String get boardAddRow => 'Add row';

  @override
  String get boardSplitOne => 'One column';

  @override
  String get boardSplitHalves => 'Two equal columns';

  @override
  String get boardSplitWideNarrow => 'Wide and narrow';

  @override
  String get boardSplitNarrowWide => 'Narrow and wide';

  @override
  String get boardSplitThirds => 'Three columns';

  @override
  String get boardMoveRowUp => 'Move row up';

  @override
  String get boardMoveRowDown => 'Move row down';

  @override
  String get boardRemoveRow => 'Remove row';

  @override
  String boardMove(String widget) {
    return 'Move “$widget”';
  }

  @override
  String get boardMoveUp => 'Up';

  @override
  String get boardMoveDown => 'Down';

  @override
  String get boardMoveLeft => 'One column left';

  @override
  String get boardMoveRight => 'One column right';

  @override
  String boardRemoved(String widget) {
    return '$widget removed';
  }

  @override
  String boardFlattened(int count) {
    return 'Layout set to $count columns';
  }

  @override
  String get boardReplaced => 'Layout replaced';

  @override
  String get boardDiscarded => 'Changes discarded';

  @override
  String boardMoved(
    String widget,
    int row,
    int column,
    int position,
    int count,
  ) {
    return '$widget: row $row, column $column, position $position of $count';
  }

  @override
  String boardMovedTo(String widget, int position, int count) {
    return '$widget moved to position $position of $count';
  }

  @override
  String boardPickedUp(String widget) {
    return '$widget picked up';
  }

  @override
  String boardDropped(String widget) {
    return '$widget dropped';
  }

  @override
  String get boardSheetSubtitle => 'Changes apply right away.';

  @override
  String get boardNew => 'New';

  @override
  String get boardRemovedHint => 'Removed · its settings are kept';

  @override
  String boardMoveUpCard(String widget) {
    return 'Move “$widget” up';
  }

  @override
  String boardMoveDownCard(String widget) {
    return 'Move “$widget” down';
  }

  @override
  String boardRemoveCard(String widget) {
    return 'Remove “$widget”';
  }

  @override
  String get boardOrderReplaced => 'Your earlier order was replaced';

  @override
  String get boardDragRow => 'Drag to move the row';

  @override
  String boardRowPickedUp(int row) {
    return 'Row $row picked up';
  }

  @override
  String boardRowDropped(int row) {
    return 'Row $row dropped';
  }

  @override
  String boardRowMovedTo(int position, int count) {
    return 'Row moved to position $position of $count';
  }

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String get budgetsBudgeted => 'Budgeted';

  @override
  String get budgetsSpent => 'Spent';

  @override
  String get budgetsLeftLabel => 'Left';

  @override
  String budgetsLeftDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Left · $days days',
      one: 'Left · 1 day',
      zero: 'Left · last day',
    );
    return '$_temp0';
  }

  @override
  String budgetsTodayDayOf(int day, int total) {
    return 'Today, day $day of $total';
  }

  @override
  String budgetsOfAmount(String amount) {
    return 'of $amount';
  }

  @override
  String budgetsOverBudget(String amount) {
    return '$amount over budget';
  }

  @override
  String budgetsUsedLeft(int percent, String amount) {
    return '$percent% used · $amount left';
  }

  @override
  String budgetsAmountLeft(String amount) {
    return '$amount left';
  }

  @override
  String budgetsInclRolledOver(String amount) {
    return 'incl. $amount rolled over';
  }

  @override
  String budgetsInclOverspentCarried(String amount) {
    return 'incl. $amount overspent carried over';
  }

  @override
  String budgetsSpentOf(String spent, String available) {
    return '$spent spent of $available';
  }

  @override
  String budgetsUnbudgetedSpent(String amount) {
    return '$amount spent in categories without a budget';
  }

  @override
  String get budgetsEmpty => 'No budgets for this period yet.';

  @override
  String get budgetsAdd => 'Add budget';

  @override
  String get budgetsCopyPrevious => 'Copy previous period';

  @override
  String budgetsFromAverage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'From $count-period average',
      one: 'From last period’s spending',
    );
    return '$_temp0';
  }

  @override
  String get budgetsFromTemplate => 'From template';

  @override
  String get budgetsSaveTemplate => 'Save as template';

  @override
  String get budgetsEditAll => 'Edit all amounts';

  @override
  String get budgetsClearPeriod => 'Remove all budgets';

  @override
  String get budgetsClearPeriodTitle => 'Remove all budgets of this period?';

  @override
  String get budgetsClearPeriodMessage => 'Transactions are not affected.';

  @override
  String get budgetsFillMenu => 'Fill';

  @override
  String budgetsFilledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count budgets set',
      one: '1 budget set',
      zero: 'No budgets set',
    );
    return '$_temp0';
  }

  @override
  String get budgetsNothingToCopy => 'The previous period has no budgets.';

  @override
  String get budgetsNoSpendingHistory => 'No spending found in those periods.';

  @override
  String get budgetsOverwriteTitle => 'Replace existing amounts?';

  @override
  String get budgetsOverwriteMessage =>
      'Categories that already have a budget in this period get the new amount; others stay unchanged.';

  @override
  String get budgetsOverwriteConfirm => 'Replace';

  @override
  String get budgetsAmountLabel => 'Budget';

  @override
  String get budgetsAmountInvalid => 'Enter an amount of 0 or more';

  @override
  String get budgetsRemove => 'Remove budget';

  @override
  String get budgetsTemplateName => 'Template name';

  @override
  String get budgetsTemplateNameRequired => 'Enter a name';

  @override
  String budgetsTemplateSaved(String name) {
    return 'Template “$name” saved';
  }

  @override
  String budgetsTemplateSummary(int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0 · $total';
  }

  @override
  String get budgetsNoTemplates =>
      'No templates yet. Save a period as a template first.';

  @override
  String budgetsBulkTotal(String amount) {
    return 'Total budgeted: $amount';
  }

  @override
  String get budgetsNoCategories => 'No expense categories yet.';

  @override
  String budgetsLeftToAssign(String amount) {
    return '$amount left to assign';
  }

  @override
  String get budgetsAllAssigned => 'Every euro is assigned';

  @override
  String budgetsOverAssigned(String amount) {
    return '$amount more assigned than available';
  }

  @override
  String budgetsEnvelopeFormula(String income, String carry, String assigned) {
    return 'Income $income + carried over $carry − assigned $assigned';
  }

  @override
  String get budgetsSelectHint => 'Select a budget to see its details.';

  @override
  String get budgetsCategoryMissing => 'This category no longer exists.';

  @override
  String get budgetsTransactionsInPeriod => 'Transactions in this period';

  @override
  String get budgetsNoTransactions => 'No transactions in this period.';

  @override
  String get budgetsSpentNoBudget => 'spent · no budget set';

  @override
  String get budgetsBudgetedThisPeriod => 'Budgeted this period';

  @override
  String get budgetsCarriedIn => 'Carried in from last period';

  @override
  String get budgetsRollsOverNext => 'Rolls over if the period ended now';

  @override
  String get budgetsWarningAt => 'Warning at';

  @override
  String get budgetsEditAmount => 'Edit budget';

  @override
  String get budgetsSetBudget => 'Set budget';

  @override
  String get budgetsRolloverOption => 'Rollover';

  @override
  String get budgetsThresholdOption => 'Warning threshold';

  @override
  String budgetsDefaultValue(String value) {
    return 'Default ($value)';
  }

  @override
  String get budgetsHistory => 'Last periods';

  @override
  String budgetsHistoryRow(String period, String spent, String budget) {
    return '$period: $spent spent, budget $budget';
  }

  @override
  String get budgetsHistoryLegend =>
      'Bars show spending; the tick marks the budget.';

  @override
  String get budgetsSplitLine => 'split';

  @override
  String budgetsAlertOverTitle(String category) {
    return '$category is over budget';
  }

  @override
  String budgetsAlertOverBody(String amount) {
    return '$amount over budget this period.';
  }

  @override
  String budgetsAlertWarningTitle(String category) {
    return '$category is nearly used up';
  }

  @override
  String budgetsAlertWarningBody(int percent, String amount) {
    return '$percent% used, $amount left.';
  }

  @override
  String budgetsAlertLowBalanceTitle(String account) {
    return 'Low balance: $account';
  }

  @override
  String budgetsAlertLowBalanceBody(String balance, String threshold) {
    return 'Balance $balance is below $threshold.';
  }

  @override
  String budgetsPlannedAmount(String amount) {
    return '$amount planned';
  }

  @override
  String budgetsPlannedOver(String amount) {
    return 'Planned: $amount over';
  }

  @override
  String budgetsAfterPlanned(String amount) {
    return 'After planned: $amount left';
  }

  @override
  String budgetsAfterPlannedOver(String amount) {
    return 'After planned: $amount over';
  }

  @override
  String get budgetsOutstanding => 'Outstanding';

  @override
  String get budgetsOutstandingHint =>
      'Not spent yet. Counts once it is booked.';

  @override
  String get budgetsUpcoming => 'Upcoming';

  @override
  String get budgetsDue => 'Due';

  @override
  String get budgetsOverdue => 'Overdue';

  @override
  String budgetsExpectedIncome(String amount) {
    return '$amount expected income, not included until it arrives';
  }

  @override
  String get budgetsRepeat => 'Repeat';

  @override
  String get budgetsRepeatOnce => 'This period only';

  @override
  String get budgetsRepeatEvery => 'Every period';

  @override
  String get budgetsRepeatCount => 'For a number of periods';

  @override
  String get budgetsRepeatUntil => 'Until a date';

  @override
  String get budgetsRepeatPeriods => 'How many times';

  @override
  String get budgetsRepeatInterval => 'Interval';

  @override
  String get budgetsRepeatNumberInvalid => 'Enter 1 or more';

  @override
  String budgetsRepeatUntilDate(String date) {
    return 'Until $date';
  }

  @override
  String budgetsEveryN(int every) {
    String _temp0 = intl.Intl.pluralLogic(
      every,
      locale: localeName,
      other: 'every $every periods',
      one: 'every period',
    );
    return '$_temp0';
  }

  @override
  String budgetsRepeatsEvery(String every, String period) {
    return 'Repeats $every from $period';
  }

  @override
  String budgetsRepeatsCount(int count, String every, String period) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Repeats $every from $period, $count times',
      one: 'Only in $period',
    );
    return '$_temp0';
  }

  @override
  String budgetsRepeatsUntil(String every, String period, String date) {
    return 'Repeats $every from $period until $date';
  }

  @override
  String get budgetsScopeChangeTitle => 'Change a repeating budget';

  @override
  String get budgetsScopeRemoveTitle => 'Remove a repeating budget';

  @override
  String get budgetsScopeThis => 'Only this period';

  @override
  String get budgetsScopeFollowing => 'This and following periods';

  @override
  String get budgetsScopeHint =>
      'Budgets you set by hand in later periods stay as they are.';

  @override
  String budgetsRemoved(String category) {
    return 'Budget for $category removed';
  }

  @override
  String get budgetsRepeatOption => 'Repeats';

  @override
  String get budgetsStopRepeating => 'Stop repeating';

  @override
  String budgetsStopRepeatingTitle(String category) {
    return 'Stop repeating $category?';
  }

  @override
  String budgetsStopRepeatingMessage(String category) {
    return 'The budget of this period stays. Later periods get no budget for $category, except budgets you set by hand.';
  }

  @override
  String budgetsStoppedRepeating(String category) {
    return '$category no longer repeats';
  }

  @override
  String get budgetsRepeatAll => 'Repeat these budgets every period';

  @override
  String budgetsRepeatAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count budgets now repeat every period',
      one: '1 budget now repeats every period',
    );
    return '$_temp0';
  }

  @override
  String get budgetsLength => 'Length';

  @override
  String budgetsLengthPeriod(String type) {
    return 'Budget period ($type)';
  }

  @override
  String get budgetsLengthWeek => 'One week';

  @override
  String get budgetsLengthMonth => 'One month';

  @override
  String get budgetsLengthQuarter => 'One quarter';

  @override
  String get budgetsLengthYear => 'One year';

  @override
  String budgetsEveryWeek(int every) {
    String _temp0 = intl.Intl.pluralLogic(
      every,
      locale: localeName,
      other: 'every $every weeks',
      one: 'every week',
    );
    return '$_temp0';
  }

  @override
  String budgetsEveryMonth(int every) {
    String _temp0 = intl.Intl.pluralLogic(
      every,
      locale: localeName,
      other: 'every $every months',
      one: 'every month',
    );
    return '$_temp0';
  }

  @override
  String budgetsEveryQuarter(int every) {
    String _temp0 = intl.Intl.pluralLogic(
      every,
      locale: localeName,
      other: 'every $every quarters',
      one: 'every quarter',
    );
    return '$_temp0';
  }

  @override
  String budgetsEveryYear(int every) {
    String _temp0 = intl.Intl.pluralLogic(
      every,
      locale: localeName,
      other: 'every $every years',
      one: 'every year',
    );
    return '$_temp0';
  }

  @override
  String budgetsOnlyIn(String period) {
    return 'Only $period';
  }

  @override
  String budgetsWindowLabel(String length, String period) {
    return '$length · $period';
  }

  @override
  String get budgetsWindowsNote =>
      'Totals don\'t include budgets with their own length.';

  @override
  String get budgetsWindowsInPeriod => 'Within this period';

  @override
  String budgetsRemovedFollowing(String category) {
    return '$category removed from this period on';
  }

  @override
  String budgetsBudgetedFor(String period) {
    return 'Budgeted for $period';
  }

  @override
  String budgetsTransactionsIn(String period) {
    return 'Transactions in $period';
  }

  @override
  String get budgetsRepeatsShort => 'repeats';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesAdd => 'Add category';

  @override
  String get categoriesAddSub => 'Add subcategory';

  @override
  String get categoriesNew => 'New category';

  @override
  String get categoriesNewSub => 'New subcategory';

  @override
  String get categoriesEdit => 'Edit category';

  @override
  String get categoriesName => 'Name';

  @override
  String get categoriesNameRequired => 'Enter a name';

  @override
  String get categoriesParent => 'Parent category';

  @override
  String get categoriesTopLevel => 'None (top level)';

  @override
  String get categoriesParentLocked =>
      'Has subcategories, so it stays top level';

  @override
  String get categoriesIcon => 'Icon';

  @override
  String get categoriesPickIcon => 'Choose an icon';

  @override
  String categoriesIconLabel(String name) {
    return 'Icon $name';
  }

  @override
  String get categoriesColor => 'Colour';

  @override
  String get categoriesColorNone => 'Default colour';

  @override
  String categoriesColorLabel(int n) {
    return 'Colour $n';
  }

  @override
  String get categoriesFavourite => 'Favourite';

  @override
  String get categoriesUnfavourite => 'Remove from favourites';

  @override
  String get categoriesFavouriteDesc => 'Shown first when picking a category';

  @override
  String get categoriesBudgetSection => 'Budget';

  @override
  String get categoriesRollover => 'Rollover';

  @override
  String categoriesUseDefault(String value) {
    return 'Budget setting ($value)';
  }

  @override
  String get categoriesWarnThreshold => 'Warning threshold';

  @override
  String get categoriesWarnThresholdHint =>
      'Leave empty to use the budget setting';

  @override
  String get categoriesThresholdInvalid => 'Enter a value from 1 to 100';

  @override
  String get categoriesArchived => 'Archived';

  @override
  String get categoriesArchivedDesc =>
      'Hidden from pickers; existing transactions keep it';

  @override
  String get categoriesArchive => 'Archive';

  @override
  String get categoriesUnarchive => 'Unarchive';

  @override
  String get categoriesShowArchived => 'Show archived';

  @override
  String get categoriesHideArchived => 'Hide archived';

  @override
  String get categoriesMoreActions => 'More actions';

  @override
  String get categoriesReorder => 'Reorder';

  @override
  String get categoriesReorderHint =>
      'Drag to reorder. Subcategories are sorted from their parent.';

  @override
  String get categoriesReorderChildren => 'Reorder subcategories';

  @override
  String categoriesSubCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subcategories',
      one: '1 subcategory',
    );
    return '$_temp0';
  }

  @override
  String categoriesUsage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
      zero: 'Not used yet',
    );
    return '$_temp0';
  }

  @override
  String get categoriesEmpty =>
      'No categories yet. Start with the default set or create your own.';

  @override
  String get categoriesEmptyExpense => 'No expense categories yet.';

  @override
  String get categoriesEmptyIncome => 'No income categories yet.';

  @override
  String get categoriesAddDefaults => 'Add default categories';

  @override
  String get categoriesMergeAction => 'Merge';

  @override
  String get categoriesMergeTitle => 'Merge?';

  @override
  String categoriesMergeConfirm(String source, String target) {
    return 'Move everything from \"$source\" into \"$target\"? Transactions, splits, budgets and subcategories move over and \"$source\" is deleted. Budgets of the same period are added up. Repeating budgets of \"$target\" stay; those of \"$source\" take over when they end.';
  }

  @override
  String categoriesMerged(String source, String target) {
    return '\"$source\" merged into \"$target\"';
  }

  @override
  String get categoriesMergeInvalid =>
      'Choose a different category of the same type.';

  @override
  String get categoriesMergeNest =>
      'A category with subcategories can only be merged into a top-level category.';

  @override
  String get categoriesInvalidParent =>
      'Choose a top-level category of the same type as parent.';

  @override
  String get categoriesHasChildrenError =>
      'A category with subcategories can\'t become a subcategory.';

  @override
  String get categoriesInUseError => 'This category is in use.';

  @override
  String get categoriesNotFound => 'This category no longer exists.';

  @override
  String get categoriesInUseTitle => 'Category in use';

  @override
  String categoriesDeleteInUse(String name, int count, int budgets) {
    return '\"$name\" is used by $count transactions and $budgets budgets. Merge it into another category to keep the history together, or archive it.';
  }

  @override
  String categoriesDeleteHasChildren(String name) {
    return 'Delete or move the subcategories of \"$name\" first.';
  }

  @override
  String get categoriesDeleted => 'Category deleted';

  @override
  String categoriesModuleOff(String module) {
    return '$module is switched off. Turn it on in Settings › Navigation & modules.';
  }

  @override
  String get categoriesOpenSettings => 'Open settings';

  @override
  String get categoriesTagsTitle => 'Tags';

  @override
  String get categoriesTagAdd => 'Add tag';

  @override
  String get categoriesTagNew => 'New tag';

  @override
  String get categoriesTagEdit => 'Edit tag';

  @override
  String get categoriesTagName => 'Tag name';

  @override
  String get categoriesTagTaken => 'A tag with this name already exists';

  @override
  String get categoriesTagsEmpty =>
      'No tags yet. Tags cut across categories, e.g. #vacation-2026 or #reimbursable.';

  @override
  String categoriesTagMergeInto(String name) {
    return 'Merge #$name into…';
  }

  @override
  String categoriesTagMergeConfirm(String source, String target) {
    return 'Move all transactions tagged #$source to #$target? #$source is deleted; transactions with both keep one tag.';
  }

  @override
  String get categoriesTagNoMergeTarget =>
      'There is no other tag to merge into.';

  @override
  String categoriesTagDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'It is removed from $count transactions.',
      one: 'It is removed from 1 transaction.',
    );
    return '$_temp0';
  }

  @override
  String get categoriesTagDeleted => 'Tag deleted';

  @override
  String get categoriesFieldsTitle => 'Custom fields';

  @override
  String get categoriesFieldAdd => 'Add field';

  @override
  String get categoriesFieldNew => 'New custom field';

  @override
  String get categoriesFieldEdit => 'Edit custom field';

  @override
  String get categoriesFieldName => 'Field name';

  @override
  String get categoriesFieldType => 'Type';

  @override
  String get categoriesFieldTypeText => 'Text';

  @override
  String get categoriesFieldTypeNumber => 'Number';

  @override
  String get categoriesFieldTypeDate => 'Date';

  @override
  String get categoriesFieldTypeSelect => 'Single choice';

  @override
  String get categoriesFieldTypeMultiselect => 'Multiple choice';

  @override
  String get categoriesFieldTypeBoolean => 'Checkbox';

  @override
  String get categoriesFieldTypeLocked =>
      'The type can\'t change because values exist.';

  @override
  String get categoriesFieldAppliesTo => 'Applies to';

  @override
  String get categoriesFieldTransactions => 'Transactions';

  @override
  String get categoriesFieldAccounts => 'Accounts';

  @override
  String get categoriesFieldOptions => 'Options';

  @override
  String get categoriesFieldOptionHint => 'New option';

  @override
  String get categoriesFieldAddOption => 'Add option';

  @override
  String get categoriesFieldOptionsRequired => 'Add at least one option';

  @override
  String categoriesFieldOptionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count options',
      one: '1 option',
    );
    return '$_temp0';
  }

  @override
  String categoriesFieldValues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count values',
      one: '1 value',
      zero: 'No values',
    );
    return '$_temp0';
  }

  @override
  String get categoriesFieldArchivedDesc =>
      'Hidden when entering data; existing values stay';

  @override
  String categoriesFieldDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Its $count stored values are deleted too.',
      one: 'Its 1 stored value is deleted too.',
    );
    return '$_temp0';
  }

  @override
  String get categoriesFieldDeleted => 'Custom field deleted';

  @override
  String get categoriesFieldsEmpty =>
      'No custom fields yet. Add fields such as \"Receipt no.\" or \"Project\" to transactions or accounts.';

  @override
  String get appTitle => 'Quiet Ledger';

  @override
  String get navHome => 'Home';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navPlan => 'Plan';

  @override
  String get navForecast => 'Forecast';

  @override
  String get navMore => 'More';

  @override
  String get navAccounts => 'Accounts';

  @override
  String get navReports => 'Reports';

  @override
  String get navSettings => 'Settings';

  @override
  String get navImport => 'Import';

  @override
  String get navExport => 'Export';

  @override
  String get navRules => 'Rules';

  @override
  String get navGoals => 'Goals';

  @override
  String get navScenarios => 'Scenarios';

  @override
  String get navCategories => 'Categories';

  @override
  String get navTags => 'Tags';

  @override
  String get navCollapseSidebar => 'Collapse sidebar';

  @override
  String get navExpandSidebar => 'Expand sidebar';

  @override
  String get addTransaction => 'Add transaction';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDone => 'Done';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonClose => 'Close';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonNone => 'None';

  @override
  String get commonAll => 'All';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonEmpty => 'Nothing here yet';

  @override
  String commonError(String message) {
    return 'Something went wrong: $message';
  }

  @override
  String commonDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get commonComingSoon => 'This screen is not available yet.';

  @override
  String get typeExpense => 'Expense';

  @override
  String get typeIncome => 'Income';

  @override
  String get typeTransfer => 'Transfer';

  @override
  String get statusCleared => 'Cleared';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusPlanned => 'Planned';

  @override
  String get privacyHiddenAmount => 'Hidden amount, tap to reveal';

  @override
  String get privacyToggle => 'Hide amounts';

  @override
  String get moreTemplates => 'Templates';

  @override
  String get bootErrorTitle => 'The database could not be opened';

  @override
  String dashCardExpand(String widget) {
    return 'Expand $widget';
  }

  @override
  String dashCardCollapse(String widget) {
    return 'Collapse $widget';
  }

  @override
  String get dashCardRows => 'Rows';

  @override
  String get dashCardExpansionSetting => 'Folded dashboard widgets';

  @override
  String dashCardBudgetsOver(int count) {
    return '$count over';
  }

  @override
  String dashCardBudgetsNear(int count) {
    return '$count near limit';
  }

  @override
  String get dashCardBudgetsOnTrack => 'All on track';

  @override
  String dashCardBudgetsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count budgets',
      one: '1 budget',
    );
    return '$_temp0';
  }

  @override
  String dashCardUpcomingNext(String name, String date) {
    return 'Next: $name · $date';
  }

  @override
  String dashCardUpcomingDue(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$count due in $_temp0';
  }

  @override
  String dashCardAccountsTotal(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '1 account',
    );
    return '$amount across $_temp0';
  }

  @override
  String dashCardGoalsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count goals',
      one: '1 goal',
    );
    return '$_temp0';
  }

  @override
  String dashCardShareOfSpending(String percent) {
    return '$percent of spending';
  }

  @override
  String dashCardLatest(String name) {
    return 'Latest: $name';
  }

  @override
  String get dashWidgetOptions => 'Widget options';

  @override
  String get dashNetWorth => 'Net worth';

  @override
  String get dashThisMonth => 'this month';

  @override
  String dashAcrossAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '1 account',
    );
    return 'across $_temp0';
  }

  @override
  String dashIn12Months(String amount) {
    return '$amount in 12 months';
  }

  @override
  String get dashNetWorthChart => 'Net worth over the last 12 months';

  @override
  String get dashLast12Months => 'Last 12 months';

  @override
  String dashSoFar(String month) {
    return '$month so far';
  }

  @override
  String get dashExpenses => 'Expenses';

  @override
  String get dashSavingsRate => 'Savings rate';

  @override
  String get dashTopCategories => 'Top categories';

  @override
  String get dashNoSpending => 'No spending in this period';

  @override
  String get dashUncategorised => 'Uncategorised';

  @override
  String get dashAllAccounts => 'All accounts';

  @override
  String get dashViewAll => 'View all';

  @override
  String get dashBudgets => 'Budgets';

  @override
  String get dashAllBudgets => 'All budgets';

  @override
  String get dashUpcoming => 'Upcoming';

  @override
  String dashNextDays(int days) {
    return 'next $days days';
  }

  @override
  String get dashCalendar => 'Calendar';

  @override
  String dashNoUpcoming(int days) {
    return 'Nothing due in the next $days days';
  }

  @override
  String get dashGoals => 'Goals';

  @override
  String get dashNoGoals => 'No savings goals yet';

  @override
  String get dashRecent => 'Recent transactions';

  @override
  String get dashNoBudgets => 'No budgets for this period';

  @override
  String get dashSetUpBudgets => 'Set up budgets';

  @override
  String dashOver(String amount) {
    return '$amount over';
  }

  @override
  String dashOf(String amount) {
    return 'of $amount';
  }

  @override
  String get dashEdit => 'Edit dashboard';

  @override
  String get dashEditTitle => 'Edit dashboard';

  @override
  String get dashAddWidget => 'Add widget';

  @override
  String get dashRemove => 'Remove';

  @override
  String get dashChooseAccount => 'Choose account';

  @override
  String get dashResetLayout => 'Reset to default';

  @override
  String get dashPrevPeriod => 'Previous period';

  @override
  String get dashNextPeriod => 'Next period';

  @override
  String get dashToday => 'Back to today';

  @override
  String get dashSearchHint => 'Search transactions';

  @override
  String get dashAutoPost => 'auto-post';

  @override
  String get dashConfirm => 'confirm';

  @override
  String dashConfirmDaysBefore(int days) {
    return 'confirm $days days before';
  }

  @override
  String get dashWelcomeEmpty =>
      'Add your first transaction to see your dashboard come alive.';

  @override
  String get dashWTypenetWorth => 'Net worth';

  @override
  String get dashWTypemonthSummary => 'Month summary';

  @override
  String get dashWTypebudgets => 'Budget progress';

  @override
  String get dashWTypeupcomingBills => 'Upcoming bills';

  @override
  String get dashWTypeforecast => 'Mini forecast';

  @override
  String get dashWTypeaccounts => 'Accounts';

  @override
  String get dashWTypegoals => 'Goal progress';

  @override
  String get dashWTypetopCategories => 'Top categories';

  @override
  String get dashWTyperecentTransactions => 'Recent transactions';

  @override
  String get dashLayoutMenu => 'Dashboard layout';

  @override
  String get dashLayoutMenuCustom => 'Dashboard layout · Custom';

  @override
  String get dashLayoutAutoHint =>
      'Quiet Ledger\'s arrangement, adapts to the window';

  @override
  String get dashLayoutCustomHint =>
      'Your arrangement, shared by your wider screens';

  @override
  String get dashLayoutPhoneAutoHint => 'Quiet Ledger\'s order';

  @override
  String get dashLayoutPhoneCustomHint => 'Your order, shared by your phones';

  @override
  String get dashLayoutArrange => 'Arrange widgets…';

  @override
  String get dashLayoutEditMenu => 'Edit dashboard…';

  @override
  String get dashLayoutAddMenu => 'Add widget…';

  @override
  String get dashLayoutExpandAll => 'Expand all';

  @override
  String get dashLayoutCollapseAll => 'Collapse all';

  @override
  String get dashLayoutArrangeTitle => 'Arrange widgets';

  @override
  String get dashLayoutRemoveFromDashboard => 'Remove from dashboard';

  @override
  String get dashLayoutEmptyColumn => 'Drag a widget here';

  @override
  String get dashLayoutResetDone => 'Dashboard reset to default';

  @override
  String get dashLayoutNotOnDashboard => 'Not on your dashboard';

  @override
  String get dashLayoutEmptyTitle => 'Your dashboard is empty';

  @override
  String get dashLayoutEmptyBody =>
      'Add widgets to see your money at a glance.';

  @override
  String get dashLayoutDescnetWorth =>
      'Total across your accounts over 12 months';

  @override
  String get dashLayoutDescmonthSummary =>
      'Income, expenses and savings rate this month';

  @override
  String get dashLayoutDescbudgets => 'How each budget is tracking this period';

  @override
  String get dashLayoutDescupcomingBills => 'Bills and income due soon';

  @override
  String get dashLayoutDescforecast => 'Projected balance of one account';

  @override
  String get dashLayoutDescaccounts => 'Balances of your accounts';

  @override
  String get dashLayoutDescgoals => 'Progress towards your savings goals';

  @override
  String get dashLayoutDesctopCategories => 'Where your money went this period';

  @override
  String get dashLayoutDescrecentTransactions => 'Your latest entries';

  @override
  String get exportTitle => 'Export & backup';

  @override
  String get exportTxnTitle => 'Transactions as CSV';

  @override
  String get exportTxnDesc =>
      'Export transactions of a period and selected accounts, e.g. for Excel.';

  @override
  String get exportPeriod => 'Period';

  @override
  String get exportPeriodThisMonth => 'This month';

  @override
  String get exportPeriodLastMonth => 'Last month';

  @override
  String get exportPeriodThisYear => 'This year';

  @override
  String get exportPeriodLastYear => 'Last year';

  @override
  String get exportPeriodLast12Months => 'Last 12 months';

  @override
  String get exportPeriodAll => 'All time';

  @override
  String get exportPeriodCustom => 'Custom…';

  @override
  String exportPeriodRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get exportAccounts => 'Accounts';

  @override
  String get exportAccountsAll => 'All accounts';

  @override
  String exportAccountsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '1 account',
    );
    return '$_temp0';
  }

  @override
  String get exportFiles => 'Files';

  @override
  String get exportLayoutFlat => 'One file';

  @override
  String get exportLayoutPerAccount => 'One per account';

  @override
  String get exportLayoutPerAccountHint => 'Saved together as a zip archive.';

  @override
  String get exportOptions => 'CSV options';

  @override
  String get exportOptionsEdit => 'Edit options';

  @override
  String get exportHeaderRow => 'Header row';

  @override
  String get exportColumns => 'Columns';

  @override
  String exportColumnsSummary(int selected, int total) {
    return '$selected of $total columns';
  }

  @override
  String get exportColumnsHint => 'Drag to change the order.';

  @override
  String get exportColumnsMin => 'Select at least one column.';

  @override
  String get exportApply => 'Apply';

  @override
  String get exportUseDefaults => 'Defaults from settings';

  @override
  String get exportPresets => 'Presets';

  @override
  String get exportPresetsEmpty => 'No saved presets yet.';

  @override
  String get exportPresetSave => 'Save as preset';

  @override
  String get exportPresetName => 'Preset name';

  @override
  String exportPresetSaved(String name) {
    return 'Preset “$name” saved';
  }

  @override
  String exportPresetDeleted(String name) {
    return 'Preset “$name” deleted';
  }

  @override
  String exportPresetApplied(String name) {
    return 'Preset “$name” applied';
  }

  @override
  String exportPresetDelete(String name) {
    return 'Delete preset “$name”';
  }

  @override
  String get exportPreview => 'Preview';

  @override
  String exportPreviewHint(int count) {
    return 'first $count rows';
  }

  @override
  String get exportPreviewEmpty =>
      'No transactions match the period and accounts.';

  @override
  String get exportRun => 'Export CSV';

  @override
  String get exportRunZip => 'Export zip';

  @override
  String exportSaved(String location) {
    return 'Saved to $location';
  }

  @override
  String get exportSavedShort => 'Export saved';

  @override
  String get exportShared => 'Export shared';

  @override
  String get exportDownloaded => 'Download started';

  @override
  String exportRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
      zero: 'No rows',
    );
    return '$_temp0';
  }

  @override
  String exportFailed(String message) {
    return 'Export failed: $message';
  }

  @override
  String get exportWorking => 'Working…';

  @override
  String get exportBackupTitle => 'Full backup';

  @override
  String get exportBackupDesc =>
      'All data and settings as a zip of CSV files with a checksum manifest. Use it as a backup or to move to another device.';

  @override
  String get exportBackupRun => 'Create backup';

  @override
  String exportBackupDone(int count) {
    return 'Backup created and verified ($count rows)';
  }

  @override
  String get exportRestoreRun => 'Restore backup…';

  @override
  String get exportRestoreTitle => 'Restore this backup?';

  @override
  String get exportRestoreCreated => 'Created';

  @override
  String get exportRestoreAppVersion => 'App version';

  @override
  String get exportRestoreDevice => 'Device';

  @override
  String get exportRestoreThisDevice => 'This device';

  @override
  String get exportRestoreOtherDevice => 'Another device';

  @override
  String get exportRestoreTotalRows => 'Rows in total';

  @override
  String get exportRestoreWarning =>
      'This replaces all data and settings on this device with the backup. A safety copy of the current data is kept on this device first (Export & backup › Safety copies).';

  @override
  String get exportRestoreBackupFirst =>
      'Also save a backup of the current data elsewhere';

  @override
  String get exportRestoreConfirm => 'Replace all data';

  @override
  String get exportRestoreAborted => 'Restore cancelled. Nothing was changed.';

  @override
  String exportRestoreDone(int count) {
    return 'Backup restored ($count rows)';
  }

  @override
  String exportRestoreFailed(String message) {
    return 'Restore failed, nothing was changed: $message';
  }

  @override
  String get exportErrTitle => 'Cannot restore';

  @override
  String get exportErrNotBundle =>
      'This file is not a backup created by this app.';

  @override
  String get exportErrNewerFormat =>
      'This backup was created by a newer version of the app. Update the app to restore it.';

  @override
  String exportErrChecksum(String file) {
    return 'The backup is damaged: $file does not match its checksum.';
  }

  @override
  String exportErrInvalid(String detail) {
    return 'The backup is damaged: $detail';
  }

  @override
  String get exportAutoTitle => 'Automatic backup';

  @override
  String get exportAutoDesc =>
      'Regularly writes a full backup to a folder, for example one that a cloud client syncs.';

  @override
  String get exportAutoSchedule => 'Schedule';

  @override
  String get exportAutoNoFolder => 'No folder chosen';

  @override
  String get exportAutoChooseFolder => 'Choose folder…';

  @override
  String exportAutoLast(String date) {
    return 'Last backup: $date';
  }

  @override
  String get exportAutoNever => 'No automatic backup yet';

  @override
  String get exportAutoRunNow => 'Back up now';

  @override
  String exportAutoRunDone(String file) {
    return 'Backup written: $file';
  }

  @override
  String exportAutoRunFailed(String message) {
    return 'Backup failed: $message';
  }

  @override
  String exportAutoKeepValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Keep the newest $count backups',
      one: 'Keep the newest backup',
    );
    return '$_temp0';
  }

  @override
  String get exportAutoUnavailable =>
      'Automatic backups to a folder are not available in the browser. Use “Create backup” instead.';

  @override
  String get exportAutoNeedsFolder =>
      'Choose a folder to start automatic backups.';

  @override
  String get exportAutoSettings => 'Automatic backup settings';

  @override
  String get exportDecrease => 'Decrease';

  @override
  String get exportIncrease => 'Increase';

  @override
  String get exportPurgeLast => 'Last clean-up of deleted entries';

  @override
  String get exportColDate => 'Date';

  @override
  String get exportColValueDate => 'Value date';

  @override
  String get exportColAccount => 'Account';

  @override
  String get exportColType => 'Type';

  @override
  String get exportColAmount => 'Amount';

  @override
  String get exportColCurrency => 'Currency';

  @override
  String get exportColPayee => 'Payee';

  @override
  String get exportColNote => 'Note';

  @override
  String get exportColCategory => 'Category';

  @override
  String get exportColSplit => 'Split';

  @override
  String get exportColTags => 'Tags';

  @override
  String get exportColStatus => 'Status';

  @override
  String get exportColTransferAccount => 'Transfer account';

  @override
  String get exportColId => 'ID';

  @override
  String get forecastTitle => 'Forecast';

  @override
  String get forecastTotal => 'All accounts';

  @override
  String get forecastChooseAccount => 'Choose account';

  @override
  String get forecastHorizon => 'Horizon';

  @override
  String forecastHorizonShort(int months) {
    return '$months mo';
  }

  @override
  String forecastHorizonLong(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get forecastHorizonCustom => 'Custom';

  @override
  String get forecastHorizonCustomTitle => 'Custom horizon';

  @override
  String get forecastHorizonMonthsLabel => 'Months';

  @override
  String forecastHorizonRangeError(int min, int max) {
    return 'Enter $min–$max months';
  }

  @override
  String get forecastLowestPoint => 'Lowest point';

  @override
  String forecastDaysBelow(int days, String limit) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days below $limit',
      one: '1 day below $limit',
    );
    return '$_temp0';
  }

  @override
  String forecastStaysAbove(Object limit) {
    return 'Stays above $limit';
  }

  @override
  String forecastLowestBelowThreshold(
    String amount,
    String date,
    String threshold,
  ) {
    return 'Lowest $amount on $date, below your $threshold threshold';
  }

  @override
  String forecastLowestBelowZero(String amount, String date) {
    return 'Lowest $amount on $date, below zero';
  }

  @override
  String forecastLowestOk(String amount, String date) {
    return 'Lowest $amount on $date';
  }

  @override
  String get forecastLegendBaseline => 'Baseline';

  @override
  String get forecastLegendThreshold => 'Threshold';

  @override
  String get forecastLegendCombined => 'All combined';

  @override
  String get forecastCombinedDesc => 'All compared scenarios applied together';

  @override
  String forecastChartSummary(
    String account,
    String start,
    String end,
    String amount,
    String date,
  ) {
    return 'Projected daily balance of $account from $start to $end. Lowest point $amount on $date.';
  }

  @override
  String forecastChartThreshold(Object threshold) {
    return 'Low-balance threshold $threshold.';
  }

  @override
  String forecastChartScenario(String name, String amount, String date) {
    return 'With $name: lowest $amount on $date.';
  }

  @override
  String get forecastScenarios => 'Scenarios';

  @override
  String get forecastEditScenarios => 'Edit scenarios';

  @override
  String get forecastHideSidePanel => 'Hide side panel';

  @override
  String get forecastShowSidePanel => 'Show side panel';

  @override
  String get forecastNoScenarios =>
      'No scenarios yet. Try a raise, a big purchase or paying off a loan early.';

  @override
  String get forecastAddScenario => 'Add scenario';

  @override
  String get forecastBalances => 'Balances';

  @override
  String get forecastMonths => 'Months';

  @override
  String get forecastBudgetPeriods => 'Budget periods';

  @override
  String get forecastColMonth => 'Month';

  @override
  String get forecastColPeriod => 'Period';

  @override
  String get forecastColLowest => 'Lowest';

  @override
  String get forecastColEnd => 'End';

  @override
  String forecastColWith(Object name) {
    return 'With $name';
  }

  @override
  String forecastPartial(Object date) {
    return 'until $date';
  }

  @override
  String get forecastWhatIf => 'Can I afford it?';

  @override
  String get forecastWhatIfAmount => 'Amount';

  @override
  String get forecastWhatIfDate => 'Date';

  @override
  String get forecastWhatIfAccount => 'From account';

  @override
  String get forecastWhatIfCheck => 'Check';

  @override
  String get forecastWhatIfHint =>
      'Checks the forecast only. Nothing is saved.';

  @override
  String forecastWhatIfQuestion(String amount, String date, String account) {
    return 'Can I afford $amount on $date from $account?';
  }

  @override
  String forecastWhatIfYes(String amount, String date) {
    return 'Yes. Afterwards your lowest balance is $amount on $date.';
  }

  @override
  String forecastWhatIfTight(String amount, String date, String threshold) {
    return 'Tight. Your balance would drop to $amount on $date, below your $threshold threshold.';
  }

  @override
  String forecastWhatIfNo(String amount, String date) {
    return 'No. Your balance would drop to $amount on $date.';
  }

  @override
  String forecastWhatIfChange(Object delta) {
    return '$delta compared with now';
  }

  @override
  String get forecastWhatIfEnterAmount => 'Enter an amount';

  @override
  String get forecastUpcoming => 'Upcoming big events';

  @override
  String get forecastNoEvents => 'No big events in this horizon.';

  @override
  String get forecastShowAll => 'Show all';

  @override
  String get forecastShowLess => 'Show less';

  @override
  String get forecastWarnings => 'Warnings';

  @override
  String forecastWarnBelowZero(String account, String date) {
    return '$account goes below zero on $date';
  }

  @override
  String forecastWarnBelowThreshold(
    String account,
    String threshold,
    String date,
  ) {
    return '$account drops below $threshold on $date';
  }

  @override
  String get forecastNoWarnings => 'No account drops below its threshold.';

  @override
  String get forecastNoAccounts =>
      'No accounts are included in the forecast yet. Add an account or turn on “Include in forecast”.';

  @override
  String get forecastAddAccount => 'Add account';

  @override
  String get forecastModuleOff =>
      'The forecast is turned off. You can turn it on in Settings › Navigation & modules.';

  @override
  String get forecastOpenSettings => 'Open settings';

  @override
  String get forecastProjection => 'Long-term projection';

  @override
  String get forecastEventRecurring => 'Recurring';

  @override
  String get forecastEventScheduled => 'Scheduled';

  @override
  String get forecastEventGoal => 'Goal contribution';

  @override
  String get forecastEventOneOff => 'Scenario';

  @override
  String get forecastEventWhatIf => 'What-if';

  @override
  String forecastTransferTo(Object account) {
    return 'To $account';
  }

  @override
  String forecastTransferFrom(Object account) {
    return 'From $account';
  }

  @override
  String forecastVariableNote(Object method) {
    return 'Includes expected variable spending: $method.';
  }

  @override
  String get forecastLoading => 'Calculating forecast…';

  @override
  String get forecastProjYears => 'Years';

  @override
  String forecastProjYearsValue(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String get forecastProjSource => 'Savings from';

  @override
  String get forecastProjSourceHistory => 'History';

  @override
  String get forecastProjSourcePlan => 'Plan';

  @override
  String forecastProjSourceHistoryDesc(Object amount) {
    return 'Average of the last 12 months: $amount per month';
  }

  @override
  String forecastProjSourcePlanDesc(Object amount) {
    return 'Recurring items and expected spending: $amount in the first month';
  }

  @override
  String get forecastProjRealDesc =>
      'In today\'s money (adjusted for inflation)';

  @override
  String forecastProjPerYear(Object value) {
    return '$value per year';
  }

  @override
  String forecastProjNetWorthOn(Object date) {
    return 'Net worth on $date';
  }

  @override
  String forecastProjToday(Object amount) {
    return 'Today: $amount';
  }

  @override
  String get forecastProjMilestones => 'Milestones';

  @override
  String get forecastProjNoMilestones => 'No milestones within this period.';

  @override
  String forecastMilestoneNetWorth(Object amount) {
    return 'Net worth reaches $amount';
  }

  @override
  String get forecastMilestoneDebtFree => 'Debt-free';

  @override
  String forecastMilestonePaidOff(Object account) {
    return '$account paid off';
  }

  @override
  String forecastMilestoneGoal(Object goal) {
    return 'Goal reached: $goal';
  }

  @override
  String forecastProjChartSummary(
    String start,
    String end,
    String startAmount,
    String endAmount,
  ) {
    return 'Projected net worth from $start to $end: $startAmount now, $endAmount at the end.';
  }

  @override
  String forecastProjChartMilestones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count milestones.',
      one: '1 milestone.',
      zero: 'No milestones.',
    );
    return '$_temp0';
  }

  @override
  String get forecastProjAssumptions => 'Assumptions';

  @override
  String get forecastProjAssets => 'Assets';

  @override
  String get forecastProjDebts => 'Debts';

  @override
  String get forecastProjNominal => 'Nominal';

  @override
  String get forecastProjReal => 'Real';

  @override
  String get forecastProjNoAccounts =>
      'No accounts are included in net worth yet.';

  @override
  String get goalsNew => 'New goal';

  @override
  String get goalsEdit => 'Edit goal';

  @override
  String get goalsEmpty =>
      'No savings goals yet. Set one to see how much to put aside each period.';

  @override
  String get goalsNoActive => 'All goals are archived.';

  @override
  String get goalsByPriority => 'By priority · drag to reorder';

  @override
  String goalsArchived(int count) {
    return 'Archived ($count)';
  }

  @override
  String get goalsShow => 'Show';

  @override
  String get goalsHide => 'Hide';

  @override
  String get goalsSelectHint => 'Select a goal to see its details.';

  @override
  String get goalsReached => 'Goal reached';

  @override
  String goalsRequiredPerPeriod(String amount, String date) {
    return 'Needs $amount per period until $date';
  }

  @override
  String goalsProjected(String date) {
    return 'At this pace: $date';
  }

  @override
  String get goalsNoPace =>
      'Set a planned contribution to see when you get there.';

  @override
  String get goalsOnTrack => 'On track';

  @override
  String get goalsBehind => 'Behind';

  @override
  String goalsOfTarget(String amount) {
    return 'of $amount';
  }

  @override
  String get goalsAddContribution => 'Add contribution';

  @override
  String get goalsReorder => 'Drag to change priority';

  @override
  String goalsSemanticProgress(String saved, String target) {
    return '$saved of $target saved';
  }

  @override
  String get goalsDeposit => 'Add';

  @override
  String get goalsWithdraw => 'Withdraw';

  @override
  String get goalsAmountInvalid => 'Enter an amount';

  @override
  String get goalsModuleOff =>
      'Goals are switched off in Settings › Navigation & modules.';

  @override
  String get goalsNotFound => 'This goal no longer exists.';

  @override
  String get goalsSaved => 'Goal saved';

  @override
  String get goalsDetails => 'Goal';

  @override
  String get goalsName => 'Name';

  @override
  String get goalsNameRequired => 'Enter a name';

  @override
  String get goalsTarget => 'Target amount';

  @override
  String get goalsTargetRequired => 'Enter a target above 0';

  @override
  String get goalsTargetDate => 'Target date';

  @override
  String get goalsNoTargetDate => 'No date';

  @override
  String get goalsLinkedAccount => 'Linked account';

  @override
  String get goalsNoAccount => 'None – track manually';

  @override
  String get goalsLinkedHelp =>
      'Progress follows the account balance; the pace comes from its last 3–6 months.';

  @override
  String get goalsSavedSoFar => 'Saved so far';

  @override
  String get goalsPlannedContribution => 'Planned contribution per period';

  @override
  String get goalsPlannedContributionHelp =>
      'Used for the projected date when there is no account history.';

  @override
  String get goalsArchive => 'Archive';

  @override
  String get goalsUnarchive => 'Restore';

  @override
  String get importTitle => 'Import';

  @override
  String importStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get importStepSource => 'Source';

  @override
  String get importStepSheets => 'Sheets';

  @override
  String get importStepStructure => 'Structure';

  @override
  String get importStepMapping => 'Map columns';

  @override
  String get importStepFormats => 'Formats';

  @override
  String get importStepValues => 'Categories & accounts';

  @override
  String get importStepTransfers => 'Transfers';

  @override
  String get importStepDuplicates => 'Duplicates';

  @override
  String get importStepSummary => 'Summary';

  @override
  String importNextStep(String step) {
    return 'Next: $step';
  }

  @override
  String importProfileLabel(String name) {
    return 'Profile: $name';
  }

  @override
  String get importWorking => 'Working…';

  @override
  String get importHistory => 'Import history';

  @override
  String get importCancelTitle => 'Leave the import?';

  @override
  String get importCancelMessage => 'Your choices for this import are lost.';

  @override
  String get importCancelConfirm => 'Leave';

  @override
  String get importSourceIntro =>
      'Import your spreadsheet history or bank exports. Several files can be imported in one batch.';

  @override
  String get importPickFiles => 'Choose files';

  @override
  String get importPickFilesHint => 'Excel (.xlsx, .xlsm, .xls), CSV or TSV';

  @override
  String get importPasteTitle => 'Paste from a spreadsheet';

  @override
  String get importPasteHint =>
      'Select rows in Excel, copy them and paste them here.';

  @override
  String get importPasteButton => 'Paste from clipboard';

  @override
  String get importPasteAdd => 'Use these rows';

  @override
  String get importPasteField => 'Pasted rows';

  @override
  String get importPasteEmpty => 'The clipboard holds no text.';

  @override
  String get importFilesTitle => 'Files in this import';

  @override
  String importFileSheets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sheets',
      one: '1 sheet',
    );
    return '$_temp0';
  }

  @override
  String importRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0';
  }

  @override
  String importFileCsvInfo(String encoding, String delimiter) {
    return '$encoding · delimiter $delimiter';
  }

  @override
  String get importRemoveFile => 'Remove';

  @override
  String get importCsvOptions => 'Reading options';

  @override
  String get importEncoding => 'Encoding';

  @override
  String get importAuto => 'Automatic';

  @override
  String get importDelimiter => 'Delimiter';

  @override
  String get importQuote => 'Quote character';

  @override
  String get importTab => 'Tab';

  @override
  String get importErrOds =>
      'OpenDocument spreadsheets (.ods) can\'t be read. Open the file in LibreOffice Calc or Excel, save it as Excel workbook (.xlsx) and import that file.';

  @override
  String get importErrNumbers =>
      'Apple Numbers files can\'t be read. In Numbers choose File › Export To › Excel and import the .xlsx file.';

  @override
  String get importErrEncrypted =>
      'This workbook is password-protected. Remove the password in Excel (File › Info › Protect Workbook), save it and try again.';

  @override
  String get importErrNotSpreadsheet =>
      'This file holds no table that can be imported.';

  @override
  String get importErrCorrupt =>
      'The file could not be read. It may be damaged or in an unsupported format.';

  @override
  String get importErrEmpty => 'The file is empty.';

  @override
  String get importProfileUse => 'Profile';

  @override
  String get importProfileNone => 'No profile – detect everything';

  @override
  String get importProfileLoadFile => 'Load profile file';

  @override
  String get importProfileInvalid => 'This file is not an import profile.';

  @override
  String get importProfileHint =>
      'A profile repeats every choice of an earlier import.';

  @override
  String get importSheetsIntro =>
      'Choose the sheets to import and where their account comes from.';

  @override
  String get importSheetHidden => 'hidden';

  @override
  String get importSheetNoData => 'No transactions found';

  @override
  String get importAccountSource => 'Account';

  @override
  String get importAccountFixed => 'One account';

  @override
  String get importAccountColumn => 'From a column';

  @override
  String get importAccountSheetName => 'Sheet name';

  @override
  String get importAccountName => 'Account name';

  @override
  String get importAccountNameHint => 'Existing or new account';

  @override
  String get importYear => 'Year for dates without year';

  @override
  String get importYearNone => 'None';

  @override
  String get importStructureIntro =>
      'Rows above the header (titles, bank details), sum rows and empty rows are skipped.';

  @override
  String get importHeaderRow => 'Header row';

  @override
  String get importHeaderRows => 'Header rows';

  @override
  String get importNoHeader => 'No header';

  @override
  String get importFirstDataRow => 'First data row';

  @override
  String get importLastDataRow => 'Last data row';

  @override
  String get importUntilEnd => 'Until the end';

  @override
  String get importRowFilters => 'Row filters';

  @override
  String get importSkipPatterns => 'Skip sum rows starting with';

  @override
  String get importSkipPatternsHint =>
      'Separate with commas; /…/ is a regular expression';

  @override
  String get importSkipWithoutDate => 'Skip rows without a date';

  @override
  String get importSkipZero => 'Skip rows without an amount';

  @override
  String get importRowData => 'Data';

  @override
  String get importRowTitle => 'Title';

  @override
  String get importRowHeader => 'Header';

  @override
  String get importRowEmpty => 'Empty';

  @override
  String get importRowSubtotal => 'Sum row';

  @override
  String get importRowNoDate => 'No date';

  @override
  String get importRowNoAmount => 'No amount';

  @override
  String get importRowAfterEnd => 'After the end';

  @override
  String get importRowInvalid => 'Unreadable';

  @override
  String importRowStats(int data, int skipped) {
    return '$data data rows · $skipped skipped';
  }

  @override
  String importPreviewMore(int shown, int total) {
    return 'Showing the first $shown of $total rows';
  }

  @override
  String get importSheetPicker => 'Sheet';

  @override
  String importSheetInfo(String file, String sheet) {
    return '$file · sheet “$sheet”';
  }

  @override
  String importInfoHeaderRow(int row) {
    return 'header in row $row';
  }

  @override
  String get importInfoNoHeader => 'no header';

  @override
  String importInfoSubtotals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subtotal rows skipped',
      one: '1 subtotal row skipped',
    );
    return '$_temp0';
  }

  @override
  String get importAmountMode => 'Amounts are written as';

  @override
  String get importAmountSigned => 'One signed';

  @override
  String get importAmountDebitCredit => 'Out + In';

  @override
  String get importAmountWithType => '+ Type col.';

  @override
  String get importInvertSign => 'Expenses are written as positive numbers';

  @override
  String get importTypeNegative => 'Type values for money out';

  @override
  String get importTypePositive => 'Type values for money in';

  @override
  String get importCategorySeparator => 'Category separator';

  @override
  String get importTagSeparator => 'Tag separator';

  @override
  String get importSeparatorNone => 'None';

  @override
  String get importSeparatorSpace => 'Space';

  @override
  String get importTargetIgnore => 'Ignore';

  @override
  String get importTargetDate => 'Date';

  @override
  String get importTargetValueDate => 'Value date';

  @override
  String get importTargetAmount => 'Amount';

  @override
  String get importTargetAmountAbs => 'Amount (without sign)';

  @override
  String get importTargetDebit => 'Amount out (debit)';

  @override
  String get importTargetCredit => 'Amount in (credit)';

  @override
  String get importTargetAmountType => 'Type (in/out)';

  @override
  String get importTargetPayee => 'Payee';

  @override
  String get importTargetNote => 'Description / note';

  @override
  String get importTargetCategory => 'Category';

  @override
  String importTargetCategorySub(String separator) {
    return 'Category › Sub (“$separator”)';
  }

  @override
  String get importTargetSubcategory => 'Subcategory';

  @override
  String get importTargetAccount => 'Account';

  @override
  String get importTargetTags => 'Tags';

  @override
  String get importTargetStatus => 'Status';

  @override
  String importTargetCustom(String name) {
    return 'Custom field: $name';
  }

  @override
  String get importTargetBalance => 'Running balance (check)';

  @override
  String importColumn(String letter) {
    return 'Column $letter';
  }

  @override
  String importBalanceCheck(int matched, int checked, String column) {
    return 'Balance check: $matched of $checked rows match column $column';
  }

  @override
  String importBadValues(int count, String rows) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count values can\'t be read',
      one: '1 value can\'t be read',
    );
    return '$_temp0 (rows $rows)';
  }

  @override
  String importMismatches(int count, String rows) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count balance mismatches',
      one: '1 balance mismatch',
    );
    return '$_temp0 (rows $rows)';
  }

  @override
  String get importApplyToSimilar => 'Use for all sheets with these columns';

  @override
  String importAppliedToSimilar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Applied to $count more sheets',
      one: 'Applied to 1 more sheet',
      zero: 'No other sheet has these columns',
    );
    return '$_temp0';
  }

  @override
  String get importNeedDateAmount =>
      'Map a date and an amount column in every sheet to continue.';

  @override
  String importInvalidCell(String value) {
    return 'Can\'t be read: $value';
  }

  @override
  String get importFormatsIntro =>
      'Formats are detected per column. Change them when values are read wrongly.';

  @override
  String get importDateFormat => 'Date format';

  @override
  String get importNumberFormat => 'Number format';

  @override
  String importDetected(String format) {
    return 'Detected: $format';
  }

  @override
  String get importDateSerial => 'Excel serial number (45000)';

  @override
  String get importDateDmy => 'Day first (31.12.2024)';

  @override
  String get importDateMdy => 'Month first (12/31/2024)';

  @override
  String get importDateYmd => 'ISO (2024-12-31)';

  @override
  String get importDateCompact => 'Compact (20241231)';

  @override
  String get importDateMonthName => 'Month name (31 Dec 2024)';

  @override
  String get importDateCells => 'Date cells';

  @override
  String get importNumberDe => '1.234,56';

  @override
  String get importNumberEn => '1,234.56';

  @override
  String get importNumberSpace => '1 234,56';

  @override
  String get importSamples => 'Examples';

  @override
  String get importIssuesTitle => 'Values that can\'t be read';

  @override
  String get importNoIssues => 'All values can be read.';

  @override
  String importIssueAt(int row, String column) {
    return 'Row $row, column $column';
  }

  @override
  String get importIssueBadDate => 'Not a date';

  @override
  String get importIssueMissingDate => 'Date missing';

  @override
  String get importIssueBadValueDate => 'Value date not readable (ignored)';

  @override
  String get importIssueBadAmount => 'Not an amount';

  @override
  String get importIssueMissingAmount => 'Amount missing';

  @override
  String get importIssueBadType => 'Unknown type value';

  @override
  String get importIssueBadBalance => 'Balance not readable (not checked)';

  @override
  String get importIssueBadStatus => 'Unknown status (ignored)';

  @override
  String get importIssueBadCustomField => 'Custom field value not readable';

  @override
  String get importIssueMissingAccount => 'No account';

  @override
  String get importIssueYearMismatch => 'Date outside the sheet\'s year';

  @override
  String importMoreIssues(int count) {
    return 'and $count more';
  }

  @override
  String get importAccountsTitle => 'Accounts';

  @override
  String get importCategoriesTitle => 'Categories';

  @override
  String get importValuesIntro =>
      'Each value from the sheets goes to an existing entry or creates a new one.';

  @override
  String importValueRows(int count, String sum) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0 · $sum';
  }

  @override
  String get importExisting => 'Existing';

  @override
  String get importCreateNew => 'Create new';

  @override
  String get importNoCategory => 'No category';

  @override
  String get importAsTransfer => 'Transfer';

  @override
  String get importTransferTo => 'Transfer to account';

  @override
  String importNewAccountName(String name) {
    return 'New account “$name”';
  }

  @override
  String importNewCategoryName(String name) {
    return 'New category “$name”';
  }

  @override
  String get importChoose => 'Choose…';

  @override
  String importSuggestion(String name) {
    return 'Suggestion: $name';
  }

  @override
  String get importAccountType => 'Account type';

  @override
  String get importCategoryKind => 'Kind';

  @override
  String get importNoCategoryColumn =>
      'The sheets have no category column. Rules and the transaction list can categorise later.';

  @override
  String get importAccTypeChecking => 'Checking';

  @override
  String get importAccTypeSavings => 'Savings';

  @override
  String get importAccTypeCash => 'Cash';

  @override
  String get importAccTypeCreditCard => 'Credit card';

  @override
  String get importAccTypeInvestment => 'Investment';

  @override
  String get importAccTypeLoan => 'Loan';

  @override
  String get importAccTypeOtherAsset => 'Other asset';

  @override
  String get importAccTypeOtherLiability => 'Other liability';

  @override
  String get importTransfersIntro =>
      'Money that left one account and arrived in another is merged into one transfer.';

  @override
  String get importDetectTransfers => 'Detect transfers';

  @override
  String get importTransferWindow => 'Maximum days apart';

  @override
  String importDaysApart(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days apart',
      one: '1 day apart',
      zero: 'same day',
    );
    return '$_temp0';
  }

  @override
  String get importTransfersNone => 'No matching pairs found.';

  @override
  String importTransfersCount(int selected, int total) {
    return '$selected of $total pairs merged';
  }

  @override
  String get importMergeAll => 'Merge all';

  @override
  String get importMergeNone => 'Merge none';

  @override
  String get importDuplicatesIntro =>
      'Rows with the same date, amount and payee/note as an existing transaction are skipped unless you include them.';

  @override
  String get importIncremental =>
      'Only import rows added since the last import of this file or profile';

  @override
  String get importDupExisting => 'Already in the app';

  @override
  String get importDupBatch => 'Twice in this import';

  @override
  String get importDupAlready => 'Imported before';

  @override
  String get importDupNone => 'No duplicates found.';

  @override
  String get importDupSkipAll => 'Skip all';

  @override
  String get importDupImportAll => 'Import all';

  @override
  String importDupIncluded(int included, int total) {
    return '$included of $total included';
  }

  @override
  String importAlreadyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows were imported before and are skipped.',
      one: '1 row was imported before and is skipped.',
    );
    return '$_temp0';
  }

  @override
  String get importSummaryReady => 'Ready to import';

  @override
  String importSummaryTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String importSummaryTransfers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'incl. $count transfers',
      one: 'incl. 1 transfer',
    );
    return '$_temp0';
  }

  @override
  String importSummarySkipped(int count) {
    return '$count duplicates skipped';
  }

  @override
  String importSummaryAlready(int count) {
    return '$count already imported';
  }

  @override
  String importSummaryInvalid(int count) {
    return '$count unreadable rows';
  }

  @override
  String importSummaryRules(int count) {
    return '$count categorised by rules';
  }

  @override
  String importSummaryNew(int accounts, int categories, int tags) {
    return 'New: $accounts accounts · $categories categories · $tags tags';
  }

  @override
  String get importResultingBalances => 'Resulting balances';

  @override
  String get importByCategory => 'By category';

  @override
  String importStartsAt(String amount) {
    return 'Starts at $amount';
  }

  @override
  String get importMatchesSheet => 'Matches the sheet';

  @override
  String importSheetSays(String amount) {
    return 'Sheet: $amount';
  }

  @override
  String get importNewBadge => 'New';

  @override
  String get importUncategorised => 'Uncategorised';

  @override
  String get importWarnings => 'Warnings';

  @override
  String importWarnInvalid(int count) {
    return '$count rows can\'t be read and will not be imported.';
  }

  @override
  String importWarnMismatch(int count, String account) {
    return '$count running-balance mismatches in $account.';
  }

  @override
  String importWarnFormulas(int count) {
    return '$count formula cells have no saved result. Open the file in Excel, save it and import again.';
  }

  @override
  String importWarnYear(int count) {
    return '$count dates lie outside their sheet\'s year.';
  }

  @override
  String importWarnUncategorised(int count) {
    return '$count transactions have no category.';
  }

  @override
  String importWarnDuplicates(int count) {
    return '$count possible duplicates will be imported.';
  }

  @override
  String get importApplyRules => 'Run rules on rows without a category';

  @override
  String get importSetOpening =>
      'Set opening balances of new accounts from the running balance';

  @override
  String get importSaveProfile => 'Save these choices as profile';

  @override
  String get importProfileName => 'Profile name';

  @override
  String importUpdateProfile(String name) {
    return 'Update profile “$name”';
  }

  @override
  String importCommit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count transactions',
      one: 'Import 1 transaction',
      zero: 'Nothing to import',
    );
    return '$_temp0';
  }

  @override
  String importFailed(String message) {
    return 'The import failed; nothing was written. $message';
  }

  @override
  String get importDoneTitle => 'Import complete';

  @override
  String importDoneMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions were imported.',
      one: '1 transaction was imported.',
    );
    return '$_temp0';
  }

  @override
  String get importShowTransactions => 'Show transactions';

  @override
  String get importAgain => 'Start another import';

  @override
  String get importUndo => 'Undo import';

  @override
  String get importUndone => 'Import undone';

  @override
  String get importHistoryTab => 'History';

  @override
  String get importProfilesTab => 'Profiles';

  @override
  String get importHistoryEmpty => 'No imports yet.';

  @override
  String get importNew => 'New import';

  @override
  String importHistoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String importHistoryLive(int live, int total) {
    return '$live of $total still present';
  }

  @override
  String importHistoryUndone(String date) {
    return 'Undone on $date';
  }

  @override
  String get importHistoryUndoTitle => 'Undo this import?';

  @override
  String importHistoryUndoMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count transactions of this import are deleted.',
      one: 'The transaction of this import is deleted.',
    );
    return '$_temp0 Accounts, categories and tags it created are removed when nothing else uses them.';
  }

  @override
  String get importHistoryUndoAction => 'Undo import';

  @override
  String get importProfilesEmpty =>
      'No profiles yet. Save one in the last step of an import.';

  @override
  String get importProfileExport => 'Export';

  @override
  String get importProfileRename => 'Rename';

  @override
  String get importProfileExported => 'Profile saved';

  @override
  String get importProfileImported => 'Profile imported';

  @override
  String get importProfileStart => 'Import with this profile';

  @override
  String get onbDefaultChecking => 'Checking account';

  @override
  String onbStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onbGetStarted => 'Get started';

  @override
  String get onbSetUpLock => 'Set up app lock';

  @override
  String get onbSkipFinish => 'Not now, finish';

  @override
  String get onbTagline =>
      'Your money, on your device. Record, track, plan and project — without a cloud account.';

  @override
  String get onbPointRecord => 'Log a transaction in seconds';

  @override
  String get onbPointTrack =>
      'See balances, net worth and where your money goes';

  @override
  String get onbPointPlan => 'Budgets, recurring bills and savings goals';

  @override
  String get onbPointProject => 'Forecast your balance months ahead';

  @override
  String get onbPointPrivate =>
      'Private: encrypted on this device, no telemetry';

  @override
  String get onbFormatsTitle => 'Language & formats';

  @override
  String get onbFormatsSubtitle =>
      'You can change all of this later in Settings.';

  @override
  String get onbPreview => 'Preview';

  @override
  String get onbPeriodTitle => 'Budget period';

  @override
  String get onbPeriodSubtitle =>
      'When does your money month start? Many people use the day their salary arrives.';

  @override
  String get onbLastDayOfMonth => 'Last day of the month';

  @override
  String get onbSalaryHint =>
      'Tip: after you add your salary as a recurring income you can let periods start on payday (Settings › Budgets).';

  @override
  String get onbStartTitle => 'How do you want to start?';

  @override
  String get onbStartSubtitle => 'Default categories are created either way.';

  @override
  String get onbImportTitle => 'Import from Excel or CSV';

  @override
  String get onbImportText =>
      'Bring your existing sheet with all its history. The importer maps columns, categories and accounts.';

  @override
  String get onbFreshTitle => 'Start fresh';

  @override
  String get onbFreshText => 'Add your accounts with their current balances.';

  @override
  String get onbAccountsTitle => 'Your accounts';

  @override
  String get onbAccountsSubtitle =>
      'Enter today\'s balance for each account. You can add more later.';

  @override
  String get onbAccountName => 'Name';

  @override
  String get onbAccountType => 'Type';

  @override
  String get onbOpeningBalance => 'Current balance';

  @override
  String get onbAddAccount => 'Add another account';

  @override
  String get onbLockTitle => 'Protect your data';

  @override
  String get onbLockSubtitle =>
      'Lock the app with a PIN, password or biometrics.';

  @override
  String get onbTypeChecking => 'Checking';

  @override
  String get onbTypeSavings => 'Savings';

  @override
  String get onbTypeCash => 'Cash';

  @override
  String get onbTypeCreditCard => 'Credit card';

  @override
  String get onbTypeInvestment => 'Investment';

  @override
  String get onbTypeLoan => 'Loan';

  @override
  String get onbTypeOtherAsset => 'Other asset';

  @override
  String get onbTypeOtherLiability => 'Other liability';

  @override
  String get planTabBudgets => 'Budgets';

  @override
  String get planTabRecurring => 'Recurring';

  @override
  String get planTabGoals => 'Goals';

  @override
  String get planBillsCalendar => 'Bills calendar';

  @override
  String get planPreviousPeriod => 'Previous period';

  @override
  String get planNextPeriod => 'Next period';

  @override
  String get planToday => 'Today';

  @override
  String planPeriodSemantics(String title, String range) {
    return 'Period $title, $range';
  }

  @override
  String get recurringNew => 'New recurring item';

  @override
  String get recurringEdit => 'Edit recurring item';

  @override
  String get recurringEmpty =>
      'No recurring items yet. Add rent, salary or subscriptions to see them coming.';

  @override
  String get recurringSelectHint => 'Select a recurring item to edit it.';

  @override
  String get recurringNext30Days => 'Next 30 days';

  @override
  String recurringBills(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bills',
      one: '1 bill',
      zero: 'No bills',
    );
    return '$_temp0';
  }

  @override
  String recurringIncomeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count incomes',
      one: '1 income',
      zero: 'No income',
    );
    return '$_temp0';
  }

  @override
  String get recurringDueTitle => 'Waiting for confirmation';

  @override
  String get recurringDueToday => 'Due today';

  @override
  String recurringOverdueDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Overdue by $days days',
      one: 'Overdue by 1 day',
    );
    return '$_temp0';
  }

  @override
  String recurringDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days days',
      one: 'Tomorrow',
    );
    return '$_temp0';
  }

  @override
  String recurringMorePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more due',
      one: '+1 more due',
    );
    return '$_temp0';
  }

  @override
  String get recurringSkip => 'Skip';

  @override
  String get recurringEditConfirm => 'Edit & confirm';

  @override
  String recurringConfirmed(String name) {
    return '“$name” posted';
  }

  @override
  String recurringSkipped(String name) {
    return '“$name” skipped';
  }

  @override
  String recurringActiveRules(int count) {
    return 'Active ($count)';
  }

  @override
  String get recurringInactiveRules => 'Paused or ended';

  @override
  String get recurringNoActive => 'No active recurring items.';

  @override
  String get recurringPaused => 'Paused';

  @override
  String get recurringEnded => 'Ended';

  @override
  String recurringNextOn(String date) {
    return 'Next $date';
  }

  @override
  String get recurringAutoPostShort => 'auto-post';

  @override
  String get recurringConfirmShort => 'confirm';

  @override
  String get recurringPostedLabel => 'posted';

  @override
  String get recurringWhat => 'What';

  @override
  String get recurringWhen => 'When';

  @override
  String get recurringPosting => 'Posting & reminders';

  @override
  String get recurringName => 'Name';

  @override
  String get recurringFromAccount => 'From account';

  @override
  String get recurringToAccount => 'To account';

  @override
  String get recurringNotSet => 'Not set';

  @override
  String get recurringSplit => 'Split across categories';

  @override
  String get recurringAddSplit => 'Add line';

  @override
  String get recurringSplitBalanced => 'Split adds up';

  @override
  String recurringSplitRemainder(String amount) {
    return '$amount not assigned';
  }

  @override
  String get recurringTags => 'Tags';

  @override
  String get recurringRepeats => 'Repeats';

  @override
  String get recurringPresetMonthly => 'Monthly on a day';

  @override
  String get recurringPresetLastDay => 'Last day of the month';

  @override
  String get recurringPresetLastBusinessDay => 'Last business day of the month';

  @override
  String get recurringPresetWeekly => 'Weekly';

  @override
  String get recurringPresetQuarterly => 'Quarterly';

  @override
  String get recurringPresetYearly => 'Yearly';

  @override
  String get recurringPresetDaily => 'Daily';

  @override
  String get recurringPresetCustom => 'Custom (RRULE)';

  @override
  String get recurringDayOfMonth => 'Day of the month';

  @override
  String get recurringMonthEndHint => 'In shorter months the last day is used.';

  @override
  String get recurringEveryNMonths => 'Every … months';

  @override
  String get recurringEveryNWeeks => 'Every … weeks';

  @override
  String get recurringEveryNYears => 'Every … years';

  @override
  String get recurringEveryNDays => 'Every … days';

  @override
  String get recurringMonth => 'Month';

  @override
  String get recurringDay => 'Day';

  @override
  String get recurringRRule => 'Recurrence rule (RRULE)';

  @override
  String get recurringRRuleHelp =>
      'RFC 5545, e.g. FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=15';

  @override
  String get recurringRRuleInvalid => 'This schedule is not valid.';

  @override
  String get recurringDecrease => 'Decrease';

  @override
  String get recurringIncrease => 'Increase';

  @override
  String get recurringStartDate => 'Starts';

  @override
  String get recurringEnds => 'Ends';

  @override
  String get recurringEndsNever => 'Never';

  @override
  String get recurringEndsOnDate => 'On date';

  @override
  String get recurringEndsAfterCount => 'After …';

  @override
  String get recurringEndDate => 'End date';

  @override
  String get recurringOccurrences => 'Number of occurrences';

  @override
  String get recurringShift => 'On weekends and holidays';

  @override
  String get recurringShiftNone => 'Keep date';

  @override
  String get recurringShiftEarlier => 'Earlier';

  @override
  String get recurringShiftLater => 'Later';

  @override
  String get recurringAutoPostHelp =>
      'Posted automatically on the due date when the app starts.';

  @override
  String get recurringRemindHelp =>
      'You confirm (or skip) each occurrence; it is not posted on its own.';

  @override
  String recurringRemindDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Remind $days days before',
      one: 'Remind 1 day before',
      zero: 'Remind on the due date',
    );
    return '$_temp0';
  }

  @override
  String get recurringNotifyTime => 'Notification time';

  @override
  String get recurringActive => 'Active';

  @override
  String get recurringActiveHelp =>
      'Paused items are not posted and not reminded.';

  @override
  String get recurringAmountChanges => 'Amount changes';

  @override
  String get recurringAmountChangesHelp =>
      'A new amount from a date (e.g. a rent increase). Earlier postings stay unchanged.';

  @override
  String get recurringAddAmountChange => 'Add amount change';

  @override
  String recurringFromDate(String date) {
    return 'From $date';
  }

  @override
  String get recurringEffectiveFrom => 'Effective from';

  @override
  String get recurringNewAmount => 'New amount';

  @override
  String get recurringNextOccurrences => 'Next occurrences';

  @override
  String get recurringNoUpcoming => 'No upcoming occurrences.';

  @override
  String recurringShiftedFrom(String date, String original) {
    return '$date (moved from $original)';
  }

  @override
  String recurringLastPosted(String date) {
    return 'Handled up to $date';
  }

  @override
  String get recurringPostedHistory => 'Posted';

  @override
  String get recurringNothingPosted => 'Nothing posted yet.';

  @override
  String get recurringSaved => 'Recurring item saved';

  @override
  String get recurringDeleteMessage => 'Already posted transactions are kept.';

  @override
  String get recurringNotFound => 'This recurring item no longer exists.';

  @override
  String get recurringErrorName => 'Enter a name';

  @override
  String get recurringErrorAmount => 'Enter an amount';

  @override
  String get recurringErrorEndBeforeStart =>
      'The end date must not be before the start date';

  @override
  String get recurringErrorCount => 'Enter at least 1';

  @override
  String get recurringErrorAccount => 'Choose an account';

  @override
  String get recurringErrorTransferAccount => 'Choose the target account';

  @override
  String get recurringErrorSameAccount => 'Choose two different accounts';

  @override
  String get recurringErrorSplits =>
      'The split lines must add up to the amount';

  @override
  String get recurringPickRule => 'Choose a recurring item';

  @override
  String get recurringPickIncome => 'Choose the salary';

  @override
  String get recurringNoIncomeRules =>
      'No recurring income yet. Add your salary as recurring income first.';

  @override
  String get recurringNothingOnDay => 'Nothing due on this day.';

  @override
  String get recurringMonthOut => 'Bills this month';

  @override
  String get recurringMonthIn => 'Income this month';

  @override
  String recurringReminderBillBody(String amount, String date) {
    return '$amount due on $date';
  }

  @override
  String recurringReminderIncomeBody(String amount, String date) {
    return '$amount expected on $date';
  }

  @override
  String get recurringChannelBills => 'Bill reminders';

  @override
  String get recurringChannelIncome => 'Income reminders';

  @override
  String get recurringChannelLowBalance => 'Low balance';

  @override
  String get recurringChannelBudgets => 'Budget alerts';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsSpendingTitle => 'Spending by category';

  @override
  String get reportsIncomeByCategoryTitle => 'Income by category';

  @override
  String get reportsIncomeExpenseTitle => 'Income vs expenses';

  @override
  String get reportsNetWorthTitle => 'Net worth';

  @override
  String get reportsCategoryTrendTitle => 'Category trend';

  @override
  String get reportsTopPayeesTitle => 'Top payees';

  @override
  String get reportsComparisonTitle => 'Period comparison';

  @override
  String get reportsPeriod => 'Period';

  @override
  String get reportsCustomRange => 'Custom range…';

  @override
  String get reportsPreviousPeriod => 'Previous period';

  @override
  String get reportsNextPeriod => 'Next period';

  @override
  String get reportsAllAccounts => 'All accounts';

  @override
  String reportsAccountsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '1 account',
    );
    return '$_temp0';
  }

  @override
  String get reportsAllTags => 'All tags';

  @override
  String reportsTagsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags',
      one: '1 tag',
    );
    return '$_temp0';
  }

  @override
  String get reportsCustomField => 'Custom field';

  @override
  String reportsCustomFieldValue(String field, String value) {
    return '$field: $value';
  }

  @override
  String get reportsChooseField => 'Field';

  @override
  String get reportsFieldValue => 'Value';

  @override
  String get reportsNoFields => 'No custom fields yet';

  @override
  String get reportsIncludeExcluded => 'Include excluded';

  @override
  String get reportsIncludeExcludedHint =>
      'Includes the categories, accounts and tags excluded in Settings › Reports';

  @override
  String get reportsClearFilters => 'Clear filters';

  @override
  String get reportsExportCsv => 'Export CSV';

  @override
  String get reportsExported => 'Report exported';

  @override
  String reportsExportFailed(String message) {
    return 'Export failed: $message';
  }

  @override
  String get reportsNoData => 'No data for this period';

  @override
  String get reportsTotal => 'Total';

  @override
  String get reportsUncategorized => 'Uncategorised';

  @override
  String get reportsOther => 'Other';

  @override
  String get reportsArchived => 'archived';

  @override
  String get reportsData => 'Data';

  @override
  String get reportsColShare => 'Share';

  @override
  String get reportsColCount => 'Transactions';

  @override
  String get reportsColPeriod => 'Period';

  @override
  String get reportsColIncome => 'Income';

  @override
  String get reportsColExpenses => 'Expenses';

  @override
  String get reportsColNet => 'Net';

  @override
  String get reportsColSavingsRate => 'Savings rate';

  @override
  String get reportsColMonth => 'Month';

  @override
  String get reportsColAssets => 'Assets';

  @override
  String get reportsColLiabilities => 'Liabilities';

  @override
  String get reportsColNetWorth => 'Net worth';

  @override
  String get reportsColAverage => 'Average';

  @override
  String get reportsColCurrent => 'Current';

  @override
  String get reportsColPrevious => 'Previous';

  @override
  String get reportsColLastYear => 'Last year';

  @override
  String get reportsColDeltaPrevious => 'Δ previous';

  @override
  String get reportsColDeltaPreviousPct => 'Δ previous %';

  @override
  String get reportsColDeltaLastYear => 'Δ last year';

  @override
  String get reportsColDeltaLastYearPct => 'Δ last year %';

  @override
  String get reportsIntervalMonth => 'Month';

  @override
  String get reportsIntervalQuarter => 'Quarter';

  @override
  String get reportsIntervalYear => 'Year';

  @override
  String get reportsIntervalBudgetPeriod => 'Budget period';

  @override
  String get reportsSortTotal => 'Total';

  @override
  String get reportsSortCount => 'Count';

  @override
  String get reportsSortAverage => 'Average';

  @override
  String get reportsAllCategories => 'All categories';

  @override
  String get reportsShowTransactions => 'Show transactions';

  @override
  String get reportsSubcategories => 'Show subcategories';

  @override
  String get reportsChooseCategories => 'Categories';

  @override
  String get reportsTopCategoriesAuto => 'Top 3 categories';

  @override
  String get reportsSavingsRate => 'Savings rate';

  @override
  String get reportsNetChange => 'Net change';

  @override
  String reportsChangeInPeriod(String amount) {
    return '$amount in this period';
  }

  @override
  String get reportsVsPrevious => 'vs previous period';

  @override
  String get reportsVsLastYear => 'vs same period last year';

  @override
  String reportsQuarterLabel(int quarter, String year) {
    return 'Q$quarter $year';
  }

  @override
  String reportsDonutSummary(String title, String total, String items) {
    return '$title, total $total. $items';
  }

  @override
  String reportsBarsSummary(int count, String income, String expenses) {
    return 'Income vs expenses over $count periods: income $income, expenses $expenses.';
  }

  @override
  String reportsLineSummary(String from, String to, String start, String end) {
    return 'Net worth from $from to $to: $start to $end.';
  }

  @override
  String reportsTrendSummary(int count, String items) {
    return 'Category trend over $count periods. $items';
  }

  @override
  String reportsPayeesSummary(String items) {
    return 'Top payees: $items';
  }

  @override
  String reportsComparisonSummary(
    String current,
    String previous,
    String lastYear,
  ) {
    return 'Total $current, previous period $previous, last year $lastYear.';
  }

  @override
  String get reportsOpenReport => 'Open report';

  @override
  String get reportsNotFound => 'Report not found';

  @override
  String get rulesTitle => 'Rules';

  @override
  String get rulesEmpty =>
      'No rules yet. Rules fill in category, tags and more when a payee, note or amount matches.';

  @override
  String get rulesAdd => 'New rule';

  @override
  String get rulesOrderHint =>
      'Rules run from top to bottom. For each field the first matching rule wins; drag to change the order.';

  @override
  String get rulesDisabled => 'Disabled';

  @override
  String get rulesEnable => 'Enabled';

  @override
  String get rulesRerun => 'Re-run rules';

  @override
  String get rulesRerunTitle => 'Re-run rules on existing transactions';

  @override
  String get rulesRerunOnlyUncategorised =>
      'Only transactions without a category';

  @override
  String get rulesRerunAllHint =>
      'Rules re-evaluate every transaction and replace existing categories, notes and status.';

  @override
  String rulesRerunPreview(int count, int scanned) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions would change',
      one: '1 transaction would change',
      zero: 'No transaction would change',
    );
    return '$_temp0 ($scanned checked)';
  }

  @override
  String get rulesRerunApply => 'Apply';

  @override
  String rulesRerunDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions updated',
      one: '1 transaction updated',
      zero: 'Nothing changed',
    );
    return '$_temp0';
  }

  @override
  String get rulesNoRules => 'There are no enabled rules.';

  @override
  String get rulesNew => 'New rule';

  @override
  String get rulesEdit => 'Edit rule';

  @override
  String get rulesName => 'Name';

  @override
  String get rulesConditions => 'If';

  @override
  String get rulesMatchAll => 'All match';

  @override
  String get rulesMatchAny => 'Any matches';

  @override
  String get rulesAddCondition => 'Add condition';

  @override
  String get rulesCondText => 'Payee / note text';

  @override
  String get rulesCondAmount => 'Amount range';

  @override
  String get rulesCondAccount => 'Account';

  @override
  String get rulesCondType => 'Type';

  @override
  String get rulesFieldPayee => 'Payee';

  @override
  String get rulesFieldNote => 'Note';

  @override
  String get rulesFieldPayeeOrNote => 'Payee or note';

  @override
  String get rulesOpContains => 'contains';

  @override
  String get rulesOpEquals => 'is';

  @override
  String get rulesOpStartsWith => 'starts with';

  @override
  String get rulesOpEndsWith => 'ends with';

  @override
  String get rulesOpRegex => 'matches regex';

  @override
  String get rulesNegate => 'Negate (does not match)';

  @override
  String get rulesText => 'Text';

  @override
  String get rulesInvalidRegex => 'Invalid regular expression';

  @override
  String get rulesAmountMin => 'From';

  @override
  String get rulesAmountMax => 'To';

  @override
  String get rulesAmountAbs => 'Ignore the sign';

  @override
  String get rulesChooseAccounts => 'Choose accounts';

  @override
  String rulesAccountsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '1 account',
      zero: 'No account',
    );
    return '$_temp0';
  }

  @override
  String get rulesRemoveCondition => 'Remove condition';

  @override
  String get rulesActions => 'Then';

  @override
  String get rulesActCategory => 'Set category';

  @override
  String get rulesActTags => 'Add tags';

  @override
  String get rulesActPayee => 'Rename payee to';

  @override
  String get rulesActNote => 'Set note';

  @override
  String get rulesActStatus => 'Set status';

  @override
  String get rulesActCustomFields => 'Set custom fields';

  @override
  String get rulesKeep => 'Don\'t change';

  @override
  String get rulesOverwrite => 'Replace existing values';

  @override
  String get rulesOverwriteHint =>
      'Otherwise the rule only fills empty fields. A payee rename always applies.';

  @override
  String get rulesApplyOnEntry => 'Apply when entering transactions';

  @override
  String get rulesApplyOnImport => 'Apply when importing';

  @override
  String get rulesTest => 'Try it';

  @override
  String get rulesTestHint => 'Enter an example to see what the rule does.';

  @override
  String get rulesTestAmount => 'Amount (negative = expense)';

  @override
  String get rulesTestMatch => 'Matches – would set:';

  @override
  String get rulesTestNoMatch => 'Doesn\'t match';

  @override
  String get rulesTestNoChange => 'Matches, but the fields are already set';

  @override
  String get rulesSaved => 'Rule saved';

  @override
  String get rulesDeleted => 'Rule deleted';

  @override
  String get rulesInvalid =>
      'Give the rule a name, at least one complete condition and one action.';

  @override
  String get rulesCreateFromTxn => 'Create rule from this transaction';

  @override
  String rulesSummaryWhen(String condition) {
    return 'When $condition';
  }

  @override
  String rulesSummaryAmount(String range) {
    return 'amount $range';
  }

  @override
  String get rulesSummaryAnd => ' and ';

  @override
  String get rulesSummaryOr => ' or ';

  @override
  String get rulesSummaryNoConditions => 'No conditions';

  @override
  String get rulesYes => 'Yes';

  @override
  String get rulesNo => 'No';

  @override
  String get scenariosTitle => 'Scenarios';

  @override
  String get scenariosNew => 'New scenario';

  @override
  String get scenariosEdit => 'Edit scenario';

  @override
  String get scenariosEmpty =>
      'No scenarios yet. A scenario changes the plan – a raise, a big purchase, ending a loan – without touching your data.';

  @override
  String get scenariosName => 'Name';

  @override
  String get scenariosNameRequired => 'Enter a name';

  @override
  String get scenariosColor => 'Colour';

  @override
  String get scenariosColorAuto => 'Automatic';

  @override
  String scenariosColorOption(int index) {
    return 'Colour $index';
  }

  @override
  String get scenariosCompare => 'Compare on the forecast';

  @override
  String get scenariosCompareDesc =>
      'Up to 5 scenarios are shown next to the baseline.';

  @override
  String get scenariosMaxCompared =>
      'Up to 5 scenarios can be compared. Turn one off first.';

  @override
  String get scenariosChanges => 'Changes';

  @override
  String get scenariosAddChange => 'Add change';

  @override
  String get scenariosNoChanges => 'No changes yet. Add one to see its effect.';

  @override
  String get scenariosDuplicate => 'Duplicate';

  @override
  String scenariosCopyName(Object name) {
    return '$name (copy)';
  }

  @override
  String get scenariosDeleteTitle => 'Delete scenario?';

  @override
  String scenariosDeleteMessage(Object name) {
    return '“$name” will be deleted. Your data is not affected.';
  }

  @override
  String get scenariosNotFound => 'This scenario no longer exists.';

  @override
  String get scenariosModuleOff =>
      'Scenarios are turned off. You can turn them on in Settings › Navigation & modules.';

  @override
  String get scenariosSaved => 'Scenario saved';

  @override
  String scenariosChangeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
      zero: 'No changes',
    );
    return '$_temp0';
  }

  @override
  String get scenariosTypeOneOff => 'One-off event';

  @override
  String get scenariosTypeCategory => 'Change spending in a category';

  @override
  String get scenariosTypeRecurringChange => 'Change a recurring item';

  @override
  String get scenariosTypeAddRecurring => 'Add a recurring item';

  @override
  String get scenariosTypeEndRecurring => 'End a recurring item';

  @override
  String get scenariosTypeReturn => 'Different return';

  @override
  String get scenariosTypeInflation => 'Different inflation';

  @override
  String get scenariosTypeUnknown => 'Unsupported change';

  @override
  String scenariosSumOneOff(String amount, String date) {
    return 'One-off · $amount on $date';
  }

  @override
  String scenariosSumPercent(String percent, String date) {
    return '$percent from $date';
  }

  @override
  String scenariosSumCategoryAbsolute(String amount, String date) {
    return '$amount per month from $date';
  }

  @override
  String scenariosSumRecurringAbsolute(String amount, String date) {
    return '$amount per payment from $date';
  }

  @override
  String scenariosSumAddRecurring(
    String amount,
    String frequency,
    String date,
  ) {
    return '$amount $frequency from $date';
  }

  @override
  String scenariosSumEndRecurring(Object date) {
    return 'Ends $date';
  }

  @override
  String scenariosSumReturnAll(Object percent) {
    return 'Return $percent on investments';
  }

  @override
  String scenariosSumReturnAccount(String percent, String account) {
    return 'Return $percent on $account';
  }

  @override
  String scenariosSumInflation(Object percent) {
    return 'Inflation $percent';
  }

  @override
  String get scenariosUnknownItem => 'Unknown';

  @override
  String get scenariosFieldLabel => 'Label';

  @override
  String get scenariosFieldDate => 'Date';

  @override
  String get scenariosFieldFrom => 'From';

  @override
  String get scenariosFieldUntil => 'Until (optional)';

  @override
  String get scenariosFieldAmount => 'Amount';

  @override
  String get scenariosFieldAccount => 'Account';

  @override
  String get scenariosFieldTransferTo => 'Transfer to (optional)';

  @override
  String get scenariosFieldCategory => 'Category';

  @override
  String get scenariosFieldRule => 'Recurring item';

  @override
  String get scenariosFieldChangeBy => 'Change by';

  @override
  String get scenariosModePercent => 'Percent';

  @override
  String get scenariosModeAmount => 'Amount';

  @override
  String get scenariosFieldPercent => 'Change in % (e.g. 5 or −10)';

  @override
  String get scenariosFieldDeltaMonthly => 'Change per month (negative = less)';

  @override
  String get scenariosFieldDeltaEach => 'Change per payment (negative = less)';

  @override
  String get scenariosFieldRepeats => 'Repeats';

  @override
  String get scenariosFreqWeekly => 'weekly';

  @override
  String get scenariosFreqMonthly => 'monthly';

  @override
  String get scenariosFreqQuarterly => 'every 3 months';

  @override
  String get scenariosFreqYearly => 'yearly';

  @override
  String get scenariosFreqCustom => 'custom';

  @override
  String get scenariosFieldReturn => 'Expected return per year in %';

  @override
  String get scenariosFieldInflation => 'Inflation per year in %';

  @override
  String get scenariosAllInvestments => 'All investments';

  @override
  String get scenariosInvalidNumber => 'Enter a valid number';

  @override
  String get scenariosRequired => 'Required';

  @override
  String get scenariosChoose => 'Choose…';

  @override
  String get scenariosNoRules => 'There are no recurring items yet.';

  @override
  String scenariosLowDelta(Object delta) {
    return 'Lowest $delta';
  }

  @override
  String scenariosEndDelta(Object delta) {
    return 'End $delta';
  }

  @override
  String get scenariosResolvesWarning => 'Stays above your threshold';

  @override
  String get scenariosCausesWarning => 'Drops below your threshold';

  @override
  String get securityLockedTitle => 'Quiet Ledger is locked';

  @override
  String get securityEnterPin => 'Enter your PIN';

  @override
  String get securityEnterPassword => 'Enter your password';

  @override
  String get securityUnlock => 'Unlock';

  @override
  String get securityUseBiometrics => 'Unlock with biometrics';

  @override
  String get securityBiometricReason => 'Unlock Quiet Ledger';

  @override
  String get securityWrongPin => 'Wrong PIN';

  @override
  String get securityWrongPassword => 'Wrong password';

  @override
  String securityAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts left before a delay',
      one: '1 attempt left before a delay',
    );
    return '$_temp0';
  }

  @override
  String securityTryAgainIn(String time) {
    return 'Too many attempts. Try again in $time.';
  }

  @override
  String get securityChecking => 'Checking…';

  @override
  String get securityDeleteDigit => 'Delete digit';

  @override
  String securityDigitsOf(int count, int total) {
    return '$count of $total digits entered';
  }

  @override
  String securityDigitsEntered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count digits entered',
      one: '1 digit entered',
      zero: 'No digits entered',
    );
    return '$_temp0';
  }

  @override
  String get securityPasswordLabel => 'Password';

  @override
  String get securityShowPassword => 'Show password';

  @override
  String get securityHidePassword => 'Hide password';

  @override
  String get securitySetupTitle => 'Set up app lock';

  @override
  String get securityChooseMethod => 'How do you want to unlock the app?';

  @override
  String get securityMethodPin => 'PIN';

  @override
  String get securityMethodPassword => 'Password';

  @override
  String get securityAlsoBiometrics => 'Also unlock with biometrics';

  @override
  String get securityAlsoBiometricsDesc =>
      'Fingerprint, face or Windows Hello. Your PIN or password stays as a fallback.';

  @override
  String get securityNewPin => 'Choose a PIN';

  @override
  String get securityConfirmPin => 'Enter the PIN again';

  @override
  String get securityNewPassword => 'Choose a password';

  @override
  String get securityConfirmPassword => 'Enter the password again';

  @override
  String get securityMismatch => 'The entries don\'t match. Try again.';

  @override
  String get securityPinDigitsOnly => 'Use digits only';

  @override
  String securityPinLength(int min, int max) {
    return '$min to $max digits';
  }

  @override
  String securityPasswordTooShort(int min) {
    return 'At least $min characters';
  }

  @override
  String get securityChangePin => 'Change PIN';

  @override
  String get securityChangePassword => 'Change password';

  @override
  String get securityChangeDesc => 'Or switch between PIN and password';

  @override
  String get securityLockNow => 'Lock now';

  @override
  String get securityLockOffDesc => 'Require a PIN or password to open the app';

  @override
  String get securityLockTimeoutDesc =>
      'How long the app may stay in the background before it locks';

  @override
  String get securityConfirmIdentity => 'Confirm it\'s you';

  @override
  String get securityCurrentPin => 'Current PIN';

  @override
  String get securityCurrentPassword => 'Current password';

  @override
  String get securityDisableTitle => 'Turn off app lock?';

  @override
  String get securityDisableMessage =>
      'Anyone with access to this device can then open the app and see your finances.';

  @override
  String get securityTurnOff => 'Turn off';

  @override
  String get securityTimeoutImmediately => 'Immediately';

  @override
  String securityTimeoutSeconds(int n) {
    return '$n s';
  }

  @override
  String securityTimeoutMinutes(int n) {
    return '$n min';
  }

  @override
  String securityTimeoutHours(int n) {
    return '$n h';
  }

  @override
  String get securityContentHidden => 'Content hidden';

  @override
  String get fieldAccount => 'Account';

  @override
  String get fieldAmount => 'Amount';

  @override
  String get fieldBalance => 'Balance';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldNote => 'Note';

  @override
  String get fieldPayee => 'Payee';

  @override
  String get fieldStatus => 'Status';

  @override
  String get setAccentScheme => 'Accent colour';

  @override
  String get setAmountColorStyle => 'Amount colours';

  @override
  String get setAppLock => 'App lock';

  @override
  String get setAutoExport => 'Automatic export';

  @override
  String get setAutoExportFolder => 'Export folder';

  @override
  String get setAutoExportKeep => 'Keep last exports';

  @override
  String get setBlockScreenshots => 'Block screenshots';

  @override
  String get setBlockScreenshotsDesc => 'Android only';

  @override
  String get setBudgetMode => 'Budget mode';

  @override
  String get setCalculatorKeypad => 'Calculator keypad';

  @override
  String get setCombineScenarios => 'Show all scenarios combined';

  @override
  String get setCombineScenariosDesc =>
      'Adds a line with all compared scenarios applied together. If several set a return or inflation rate, the last one wins.';

  @override
  String get setConfirmDelete => 'Confirm before deleting';

  @override
  String get setAccentAppIcon => 'App icon in accent colour';

  @override
  String get setAccentAppIconDesc =>
      'The home-screen icon uses the preset closest to your accent. iOS asks to confirm each change.';

  @override
  String get setSidebarCollapsed => 'Collapse the sidebar';

  @override
  String get setForecastSidePanelHidden => 'Hide the forecast side panel';

  @override
  String get setCsvDateFormat => 'CSV date format';

  @override
  String get setCsvDecimalSeparator => 'CSV decimal separator';

  @override
  String get setCsvDelimiter => 'CSV delimiter';

  @override
  String get setCsvEncoding => 'CSV encoding';

  @override
  String get setCustomAccent => 'Custom accent';

  @override
  String get setDashboardPeriod => 'Dashboard period';

  @override
  String get setDateFormat => 'Date format';

  @override
  String get setDefaultAccount => 'Default account';

  @override
  String get setDefaultCategorySet => 'Default categories';

  @override
  String get setDefaultDate => 'Default date';

  @override
  String get setDefaultFilter => 'Default filter';

  @override
  String get setDefaultPostingMode => 'Default posting mode';

  @override
  String get setDefaultReturn => 'Default expected return';

  @override
  String get setDefaultReturnDesc =>
      'Per year, for accounts without their own value';

  @override
  String get setDefaultRollover => 'Default rollover';

  @override
  String get setDefaultType => 'Default type';

  @override
  String get setDensity => 'Density';

  @override
  String get setDeviceName => 'Device name';

  @override
  String get setDynamicColor => 'Dynamic colour';

  @override
  String get setDynamicColorDesc =>
      'Use the system accent colour (Material You)';

  @override
  String get setExcludedAccounts => 'Excluded accounts';

  @override
  String get setExcludedCategories => 'Excluded categories';

  @override
  String get setExcludedTags => 'Excluded tags';

  @override
  String get setFieldOrder => 'Quick-add field order';

  @override
  String get setFirstDayOfWeek => 'First day of week';

  @override
  String get setFiscalYearStart => 'Fiscal year starts in month';

  @override
  String get setFiscalYearStartDesc => '1 = January';

  @override
  String get setFormatLocale => 'Number & date format';

  @override
  String get setFormatLocaleDesc => 'Region used to format numbers and dates';

  @override
  String get setGrouping => 'Grouping';

  @override
  String get setHideAmounts => 'Hide amounts';

  @override
  String get setHideAmountsDesc => 'Blur amounts until tapped';

  @override
  String get setHideInAppSwitcher => 'Hide content in app switcher';

  @override
  String get setHighContrast => 'High contrast';

  @override
  String get setHolidayCountry => 'Holiday calendar';

  @override
  String get setHolidayRegion => 'Federal state';

  @override
  String get setHorizonMonths => 'Forecast horizon (months)';

  @override
  String get setImportProfiles => 'Import profiles & history';

  @override
  String get setIncludePending => 'Include pending';

  @override
  String get setIncludePlanned => 'Include planned';

  @override
  String get setInflation => 'Inflation rate';

  @override
  String get setLanguage => 'Language';

  @override
  String get setLockMethod => 'Unlock method';

  @override
  String get setLockOnStart => 'Lock on start';

  @override
  String get setLockTimeout => 'Lock after (in background)';

  @override
  String get setLowBalanceThreshold => 'Low-balance threshold';

  @override
  String get setManageCategories => 'Manage categories';

  @override
  String get setManageCustomFields => 'Manage custom fields';

  @override
  String get setManageTags => 'Manage tags';

  @override
  String get setModAttachments => 'Attachments';

  @override
  String get setModBudgets => 'Budgets';

  @override
  String get setModCustomFields => 'Custom fields';

  @override
  String get setNavTabs => 'Navigation tabs';

  @override
  String get setNavTabsDesc => 'Choose and order the tabs';

  @override
  String get setNotificationTime => 'Notification time';

  @override
  String get setNotifyBills => 'Notify about bills';

  @override
  String get setNotifyBudget => 'Notify about budgets';

  @override
  String get setNotifyIncome => 'Notify about income';

  @override
  String get setNotifyLowBalance => 'Notify about low balance';

  @override
  String get setOnboardingDone => 'Onboarding completed';

  @override
  String get setOptAmber => 'Amber';

  @override
  String get setOptAutoPost => 'Post automatically';

  @override
  String get setOptBiWeekly => 'Every two weeks';

  @override
  String get setOptBiometric => 'Biometrics';

  @override
  String get setOptBlue => 'Blue';

  @override
  String get setOptBudgetPeriod => 'Budget period';

  @override
  String get setOptCalendarMonth => 'Calendar month';

  @override
  String get setOptColorCoded => 'Colour-coded';

  @override
  String get setOptComfortable => 'Comfortable';

  @override
  String get setOptComma => 'comma';

  @override
  String get setOptCompact => 'Compact';

  @override
  String get setOptCustom => 'Custom';

  @override
  String get setOptDaily => 'Daily';

  @override
  String get setOptDark => 'Dark';

  @override
  String get setOptDay => 'Day';

  @override
  String get setOptEnvelope => 'Envelope (zero-based)';

  @override
  String get setOptFromBudget => 'From budget';

  @override
  String get setOptFromLanguage => 'From language';

  @override
  String get setOptLargestFirst => 'Largest first';

  @override
  String get setOptLastMonth => 'Last month';

  @override
  String get setOptLastUsed => 'Last used';

  @override
  String get setOptLastYear => 'Last year';

  @override
  String get setOptLight => 'Light';

  @override
  String get setOptLocaleDefault => 'Locale default';

  @override
  String get setOptMonday => 'Monday';

  @override
  String get setOptMonth => 'Month';

  @override
  String get setOptMonthly => 'Monthly';

  @override
  String get setOptNationwide => 'Nationwide only';

  @override
  String get setOptNeutral => 'Neutral';

  @override
  String get setOptNewestFirst => 'Newest first';

  @override
  String get setOptNextBusinessDay => 'Next business day';

  @override
  String get setOptNoRollover => 'No rollover';

  @override
  String get setOptNoShift => 'Don\'t shift';

  @override
  String get setOptOff => 'Off';

  @override
  String get setOptOldestFirst => 'Oldest first';

  @override
  String get setOptPassword => 'Password';

  @override
  String get setOptPoint => 'point';

  @override
  String get setOptPreviousBusinessDay => 'Previous business day';

  @override
  String get setOptQuarterly => 'Quarterly';

  @override
  String get setOptRemindConfirm => 'Remind & confirm';

  @override
  String get setOptRolloverBoth => 'Leftover and overspent';

  @override
  String get setOptRolloverLeftover => 'Carry leftover';

  @override
  String get setOptRolloverOverspent => 'Carry overspent';

  @override
  String get setOptRose => 'Rose';

  @override
  String get setOptSaturday => 'Saturday';

  @override
  String get setOptSemicolon => 'semicolon';

  @override
  String get setOptSignOnly => '+/− only';

  @override
  String get setOptSlate => 'Slate';

  @override
  String get setOptSmallestFirst => 'Smallest first';

  @override
  String get setOptSpruce => 'Spruce';

  @override
  String get setOptSunday => 'Sunday';

  @override
  String get setOptSystem => 'System';

  @override
  String get setOptThisMonth => 'This month';

  @override
  String get setOptThisYear => 'This year';

  @override
  String get setOptToday => 'Today';

  @override
  String get setOptTracking => 'Tracking (limits)';

  @override
  String get setOptViolet => 'Violet';

  @override
  String get setOptWeek => 'Week';

  @override
  String get setOptWeekly => 'Weekly';

  @override
  String get setOptYearToDate => 'Year to date';

  @override
  String get setOptYearly => 'Yearly';

  @override
  String get setPayeeSuggestions => 'Payee suggestions';

  @override
  String get setPayeeSuggestionsDesc =>
      'Learn category and account from history';

  @override
  String get setPeriodType => 'Period';

  @override
  String get setPrivacyOnStart => 'Privacy mode on start';

  @override
  String get setProjectionYears => 'Projection years';

  @override
  String get setQuietHoursEnd => 'Quiet hours end';

  @override
  String get setQuietHoursStart => 'Quiet hours start';

  @override
  String get setRealValues => 'Show real values';

  @override
  String get setRealValuesDesc => 'Adjust projections for inflation';

  @override
  String get setRecentCategories => 'Recent categories shown';

  @override
  String get setReminderLeadDays => 'Remind days before';

  @override
  String get setReportPeriod => 'Default period';

  @override
  String get setRequiredFields => 'Required fields';

  @override
  String get setRunningBalance => 'Running balance';

  @override
  String get setRunningBalanceDesc => 'Show the balance after each transaction';

  @override
  String get setSalaryBased => 'Start on payday';

  @override
  String get setSalaryBasedDesc =>
      'The period starts when the chosen income arrives';

  @override
  String get setShowOutstanding => 'Show planned and upcoming';

  @override
  String get setShowOutstandingDesc =>
      'Planned entries and recurring items not booked yet appear in budgets, marked as outstanding';

  @override
  String get setSalaryRule => 'Salary income';

  @override
  String get setSecAppearance => 'Appearance';

  @override
  String get setSecBudgets => 'Budgets';

  @override
  String get setSecCategories => 'Categories & tags';

  @override
  String get setSecDashboard => 'Dashboard';

  @override
  String get setSecData => 'Data';

  @override
  String get setSecEntry => 'Entry';

  @override
  String get setSecForecast => 'Forecast & projection';

  @override
  String get setSecGeneral => 'General';

  @override
  String get setSecImportExport => 'Import / export';

  @override
  String get setSecNavigation => 'Navigation & modules';

  @override
  String get setSecPrivacy => 'Privacy';

  @override
  String get setSecRecurring => 'Recurring & reminders';

  @override
  String get setSecSecurity => 'Security';

  @override
  String get setShowCents => 'Show cents';

  @override
  String get setSignStyle => 'Negative amounts';

  @override
  String get setSort => 'Sort order';

  @override
  String get setStartDay => 'Start day of month';

  @override
  String get setStartDayDesc => '0 = last day of the month';

  @override
  String get setStartScreen => 'Start screen';

  @override
  String get setStorageLocation => 'Storage location';

  @override
  String get setTextScale => 'Text size';

  @override
  String get setThemeMode => 'Theme';

  @override
  String get setTombstoneDays => 'Keep deleted items (days)';

  @override
  String get setTombstoneDaysDesc => 'Needed later for sync';

  @override
  String get setUpcomingDays => 'Upcoming bills window (days)';

  @override
  String get setVariableMethod => 'Variable spending estimate';

  @override
  String get setVisibleColumns => 'Visible columns';

  @override
  String get setWarnThreshold => 'Warning threshold';

  @override
  String get setWeekendShift => 'Weekend & holiday shift';

  @override
  String setModuleEnabled(String module) {
    return 'Enable $module';
  }

  @override
  String setOptMean(int n) {
    return 'Average of last $n months';
  }

  @override
  String setOptMedian(int n) {
    return 'Median of last $n months';
  }

  @override
  String setOptLastNMonths(int n) {
    return 'Last $n months';
  }

  @override
  String get setSettingsTitle => 'Settings';

  @override
  String get settingsUiSearchHint => 'Search settings';

  @override
  String settingsUiNoResults(String query) {
    return 'No settings match “$query”';
  }

  @override
  String get settingsUiClear => 'Clear';

  @override
  String get settingsUiSecAbout => 'About';

  @override
  String settingsUiAboutSummary(String version) {
    return 'Version $version';
  }

  @override
  String get settingsUiAboutVersion => 'Version';

  @override
  String get settingsUiAboutLicenses => 'Open-source licences';

  @override
  String get settingsUiAboutPrivacy =>
      'All data stays on this device. No account, no telemetry.';

  @override
  String get settingsUiAboutEncryption => 'Database encryption';

  @override
  String get settingsUiAboutEncryptionOn =>
      'On (SQLite3 Multiple Ciphers, key in the system keystore)';

  @override
  String get settingsUiAboutEncryptionOff =>
      'Off: no secure key storage was available when the database was created';

  @override
  String get settingsUiAboutEncryptionUnavailable =>
      'Not available on this platform';

  @override
  String get settingsUiAmountsHidden => 'Amounts hidden';

  @override
  String get settingsUiAmountsVisible => 'Amounts visible';

  @override
  String settingsUiTabsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tabs',
      one: '1 tab',
    );
    return '$_temp0';
  }

  @override
  String settingsUiDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days before',
      one: '1 day before',
      zero: 'On the day',
    );
    return '$_temp0';
  }

  @override
  String settingsUiMonthsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get settingsUiModuleOff => 'Module off';

  @override
  String settingsUiModuleOffNotice(String module) {
    return 'The $module module is switched off.';
  }

  @override
  String get settingsUiTurnOn => 'Turn on';

  @override
  String get settingsUiDataSummary => 'Storage, statistics, reset';

  @override
  String get settingsUiResetSection => 'Reset section';

  @override
  String settingsUiResetSectionTitle(String section) {
    return 'Reset “$section”?';
  }

  @override
  String get settingsUiResetSectionMessage =>
      'All settings in this section return to their defaults.';

  @override
  String get settingsUiResetDone => 'Section reset';

  @override
  String get settingsUiModulesTitle => 'Modules';

  @override
  String get settingsUiModulesDesc =>
      'Switched-off modules disappear from navigation and settings. Their data is kept.';

  @override
  String settingsUiNavTabsHint(int min, int max) {
    return '$min to $max tabs, “More” is always last';
  }

  @override
  String get settingsUiNavTabsRecommend =>
      'Tip: keep Home or Transactions in the bar.';

  @override
  String get settingsUiNavTabModuleOff =>
      'Hidden while the module is switched off';

  @override
  String get settingsUiNavMoreAlways => 'Always shown, always last';

  @override
  String get settingsUiDragHandle => 'Drag to reorder';

  @override
  String get settingsUiMoveUp => 'Move up';

  @override
  String get settingsUiMoveDown => 'Move down';

  @override
  String get settingsUiNotSet => 'Not set';

  @override
  String settingsUiAndMore(int count) {
    return '+$count more';
  }

  @override
  String get settingsUiLastDay => 'Last day';

  @override
  String get settingsUiDecrease => 'Decrease';

  @override
  String get settingsUiIncrease => 'Increase';

  @override
  String get settingsUiTapToType => 'Double-tap to type a value';

  @override
  String get settingsUiInvalidNumber => 'Enter a number';

  @override
  String get settingsUiInvalidValue => 'This value is not allowed';

  @override
  String settingsUiOutOfRange(int min, int max) {
    return 'Enter a value from $min to $max';
  }

  @override
  String settingsUiOutOfRangeText(String min, String max) {
    return 'From $min to $max';
  }

  @override
  String get settingsUiPresets => 'Presets';

  @override
  String get settingsUiCustomColor => 'Custom colour';

  @override
  String get settingsUiHue => 'Hue';

  @override
  String get settingsUiSaturation => 'Saturation';

  @override
  String get settingsUiLightness => 'Lightness';

  @override
  String get settingsUiHex => 'HEX';

  @override
  String get settingsUiInvalidHex => 'Enter a colour like #1F5A53';

  @override
  String get settingsUiNoTags => 'No tags yet';

  @override
  String get settingsUiPrivacyNow => 'Hide amounts now';

  @override
  String get settingsUiPrivacyNowDesc => 'Privacy mode for this session';

  @override
  String get settingsUiStats => 'Database statistics';

  @override
  String get settingsUiStatRecurring => 'Recurring rules';

  @override
  String get settingsUiStatImports => 'Imports';

  @override
  String get settingsUiStatChangeLog => 'Change log entries';

  @override
  String get settingsUiStatDbSize => 'Database size';

  @override
  String get settingsUiRefresh => 'Refresh';

  @override
  String get settingsUiRebuildIndex => 'Rebuild search index';

  @override
  String get settingsUiRebuildIndexDesc =>
      'Fixes missing or outdated search results';

  @override
  String get settingsUiRebuildDone => 'Search index rebuilt';

  @override
  String get settingsUiRerunRules => 'Re-run rules';

  @override
  String get settingsUiRerunRulesDesc =>
      'Apply your categorisation rules to existing transactions';

  @override
  String get settingsUiRerunRulesAll => 'Re-evaluate all transactions';

  @override
  String get settingsUiRerunRulesAllDesc =>
      'Rule values replace existing categories, not only empty ones';

  @override
  String settingsUiRerunRulesDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions changed',
      one: '1 transaction changed',
      zero: 'No transactions changed',
    );
    return '$_temp0';
  }

  @override
  String get settingsUiRun => 'Run';

  @override
  String get settingsUiResetApp => 'Reset app';

  @override
  String get settingsUiResetAppDesc =>
      'Delete all data on this device and start over';

  @override
  String get settingsUiResetAppTitle => 'Delete all data?';

  @override
  String settingsUiResetAppMessage(String word) {
    return 'This deletes every account, transaction, budget, rule and setting on this device, and the app lock. Type $word to confirm.';
  }

  @override
  String get settingsUiResetAppWord => 'DELETE';

  @override
  String settingsUiTypeToConfirm(String word) {
    return 'Type $word';
  }

  @override
  String get settingsUiResetAppConfirm => 'Delete everything';

  @override
  String get settingsUiStorageDefault => 'Default app folder';

  @override
  String get settingsUiStorageMoveTitle => 'Change storage location?';

  @override
  String settingsUiStorageMoveMessage(String path) {
    return 'The current database is copied to $path and used from there after the next restart. The old file stays where it is.';
  }

  @override
  String settingsUiStorageExisting(String path) {
    return '$path already contains a database. It will be used after the next restart; nothing is copied. It must have been created with this installation, otherwise it cannot be opened.';
  }

  @override
  String get settingsUiStorageCopy => 'Copy and switch';

  @override
  String get settingsUiStorageUseExisting => 'Use this database';

  @override
  String get settingsUiStorageRestart =>
      'Restart the app to use the new location.';

  @override
  String get settingsUiStorageResetDefault => 'Use default folder';

  @override
  String get settingsUiStorageResetMessage =>
      'After the next restart the app uses the database in its default folder again. Data stored in the custom folder is not copied back.';

  @override
  String get settingsUiStatDeleted => 'Deleted items kept for sync';

  @override
  String get settingsUiPurge => 'Purge deleted items';

  @override
  String settingsUiPurgeDesc(int days) {
    return 'Remove items deleted more than $days days ago';
  }

  @override
  String settingsUiPurgeMessage(int days) {
    return 'Permanently removes items that were deleted more than $days days ago. They can no longer be restored or synced.';
  }

  @override
  String get settingsUiPurgeConfirm => 'Purge';

  @override
  String settingsUiPurgeDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items removed',
      one: '1 item removed',
      zero: 'Nothing to purge',
    );
    return '$_temp0';
  }

  @override
  String get txnSearchHint => 'Search payee, note, category';

  @override
  String get txnSearchLabel => 'Search transactions';

  @override
  String get txnSearchHintWide => 'Payee, note, tag, category';

  @override
  String get txnSelectMultiple => 'Select multiple';

  @override
  String get txnCtrl => 'Ctrl';

  @override
  String txnEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get txnIn => 'In';

  @override
  String get txnOut => 'Out';

  @override
  String get txnToday => 'Today';

  @override
  String get txnYesterday => 'Yesterday';

  @override
  String txnTodayDate(String date) {
    return 'Today, $date';
  }

  @override
  String txnYesterdayDate(String date) {
    return 'Yesterday, $date';
  }

  @override
  String txnGroupToday(String date) {
    return 'Today · $date';
  }

  @override
  String txnGroupYesterday(String date) {
    return 'Yesterday · $date';
  }

  @override
  String txnTransferTo(String account) {
    return 'To $account';
  }

  @override
  String txnTransferFrom(String account) {
    return 'From $account';
  }

  @override
  String txnTransferFromSub(String account) {
    return 'Transfer · from $account';
  }

  @override
  String txnTransferToSub(String account) {
    return 'Transfer · to $account';
  }

  @override
  String txnSplitCount(int count) {
    return 'Split · $count';
  }

  @override
  String get txnNoPayee => 'No payee';

  @override
  String get txnUncategorized => 'Uncategorized';

  @override
  String get txnUnknownAccount => 'Unknown account';

  @override
  String get txnHasReceipt => 'Has receipt';

  @override
  String get txnRecurring => 'Recurring';

  @override
  String txnBalanceShort(String amount) {
    return 'Bal. $amount';
  }

  @override
  String get txnEmpty =>
      'No transactions yet. Add your first one with the + button.';

  @override
  String get txnEmptyFiltered => 'No transactions match these filters.';

  @override
  String get txnClearFilters => 'Clear filters';

  @override
  String get txnFilters => 'Filters';

  @override
  String get txnFilterAllDates => 'All dates';

  @override
  String get txnFilterType => 'Type';

  @override
  String get txnFilterTag => 'Tag';

  @override
  String get txnFilterCustomField => 'Custom field';

  @override
  String txnChipCount(String label, int count) {
    return '$label · $count';
  }

  @override
  String get txnSaveFilter => 'Save filter';

  @override
  String get txnPresetThisMonth => 'This month';

  @override
  String get txnPresetLastMonth => 'Last month';

  @override
  String get txnPresetLast30 => 'Last 30 days';

  @override
  String get txnPresetLast90 => 'Last 90 days';

  @override
  String get txnPresetThisYear => 'This year';

  @override
  String get txnPresetLastYear => 'Last year';

  @override
  String get txnPresetCustom => 'Custom range…';

  @override
  String get txnAmountMin => 'At least';

  @override
  String get txnAmountMax => 'At most';

  @override
  String get txnAmountHint => 'Compares the amount without sign.';

  @override
  String txnAmountAtLeast(String amount) {
    return '≥ $amount';
  }

  @override
  String txnAmountAtMost(String amount) {
    return '≤ $amount';
  }

  @override
  String get txnApply => 'Apply';

  @override
  String get txnChooseCategories => 'Choose categories';

  @override
  String get txnCustomFieldAny => 'Has any value';

  @override
  String get txnCustomFieldEquals => 'Is';

  @override
  String get txnCustomFieldContains => 'Contains';

  @override
  String get txnCustomFieldIncludes => 'Includes';

  @override
  String get txnCustomFieldValue => 'Value';

  @override
  String get txnCustomFieldAdd => 'Add condition';

  @override
  String get txnCustomFieldChoose => 'Field';

  @override
  String get txnCustomFieldNone => 'No custom fields for transactions yet.';

  @override
  String get txnSavedFilters => 'Saved filters';

  @override
  String get txnAllTransactions => 'All transactions';

  @override
  String get txnFilterName => 'Name';

  @override
  String get txnFilterSaved => 'Filter saved';

  @override
  String get txnFilterUpdated => 'Filter updated';

  @override
  String get txnUpdateFilter => 'Update with current filter';

  @override
  String get txnRename => 'Rename';

  @override
  String get txnSetDefault => 'Use as default';

  @override
  String get txnUnsetDefault => 'Stop using as default';

  @override
  String get txnIsDefault => 'Default';

  @override
  String get txnFilterDeleted => 'Filter deleted';

  @override
  String get txnNoSavedFilters =>
      'No saved filters yet. Set filters in the transaction list and tap “Save filter”.';

  @override
  String get txnNoDefaultFilter => 'No default filter';

  @override
  String get txnNameRequired => 'Enter a name';

  @override
  String get txnViewOptions => 'View options';

  @override
  String get txnGroupingOffHint => 'Grouping applies when sorted by date.';

  @override
  String get txnRunningBalanceHint =>
      'The running balance is shown when the list is filtered to one account and sorted by date.';

  @override
  String get txnChooseAccountAction => 'Choose account';

  @override
  String txnSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get txnSelectAll => 'Select all';

  @override
  String get txnClearSelection => 'Clear selection';

  @override
  String get txnSetCategory => 'Set category';

  @override
  String get txnSetStatus => 'Set status';

  @override
  String get txnSetDate => 'Set date';

  @override
  String get txnSetAccount => 'Move to account';

  @override
  String get txnAddTags => 'Add tags';

  @override
  String txnBulkUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions updated',
      one: '1 transaction updated',
    );
    return '$_temp0';
  }

  @override
  String txnDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions deleted',
      one: 'Transaction deleted',
    );
    return '$_temp0';
  }

  @override
  String txnDeleteConfirmTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count transactions?',
      one: 'Delete this transaction?',
    );
    return '$_temp0';
  }

  @override
  String get txnDeleteConfirmBody => 'You can undo this right afterwards.';

  @override
  String get txnDuplicate => 'Duplicate';

  @override
  String get txnDuplicated => 'Transaction duplicated';

  @override
  String get txnMarkCleared => 'Mark as cleared';

  @override
  String get txnMarkPending => 'Mark as pending';

  @override
  String get txnStatusChanged => 'Status changed';

  @override
  String get txnSaveAsTemplate => 'Save as template';

  @override
  String get txnTemplateSaved => 'Template saved';

  @override
  String get txnOpen => 'Open';

  @override
  String get txnSelect => 'Select';

  @override
  String get txnMoreActions => 'More actions';

  @override
  String get txnDetailTitle => 'Transaction';

  @override
  String get txnEditTransaction => 'Edit transaction';

  @override
  String get txnCloseDetail => 'Close detail';

  @override
  String get txnNotFound => 'This transaction no longer exists.';

  @override
  String get txnSplit => 'Split';

  @override
  String get txnCustomFields => 'Custom fields';

  @override
  String get txnAttachments => 'Attachments';

  @override
  String txnAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Attachments · $count files',
      one: 'Attachment · 1 file',
    );
    return '$_temp0';
  }

  @override
  String get txnAddAttachment => 'Add attachment';

  @override
  String get txnAttachReceipt => 'Attach receipt';

  @override
  String txnRemoveAttachment(String name) {
    return 'Remove attachment $name';
  }

  @override
  String get txnAttachmentUnavailable =>
      'The file is not available on this device.';

  @override
  String get txnAttachmentPending => 'Saved with the transaction';

  @override
  String get txnShare => 'Share';

  @override
  String get txnOrigin => 'Origin';

  @override
  String txnOriginRecurring(String name) {
    return 'Recurring: $name';
  }

  @override
  String txnOriginImport(String file) {
    return 'Imported from $file';
  }

  @override
  String get txnOriginManual => 'Entered manually';

  @override
  String get txnValueDate => 'Value date';

  @override
  String get txnNewTransaction => 'New transaction';

  @override
  String get txnNewTemplate => 'New template';

  @override
  String get txnEditTemplate => 'Edit template';

  @override
  String get txnSaveExpense => 'Save expense';

  @override
  String get txnSaveIncome => 'Save income';

  @override
  String get txnSaveTransfer => 'Save transfer';

  @override
  String get txnSaveChanges => 'Save changes';

  @override
  String get txnSaveTemplate => 'Save template';

  @override
  String get txnSplitAction => 'Split across categories';

  @override
  String get txnRecentCategories => 'Recent categories';

  @override
  String get txnFromAccount => 'From';

  @override
  String get txnToAccount => 'To';

  @override
  String get txnChooseAccount => 'Choose account';

  @override
  String get txnChooseCategory => 'Choose category';

  @override
  String get txnKeypad => 'Amount keypad';

  @override
  String get txnDecimalSeparator => 'Decimal separator';

  @override
  String get txnDeleteDigit => 'Delete digit';

  @override
  String get txnPlus => 'Plus';

  @override
  String get txnMinus => 'Minus';

  @override
  String get txnTimes => 'Times';

  @override
  String get txnDivide => 'Divided by';

  @override
  String txnAmountPreview(String amount) {
    return '= $amount';
  }

  @override
  String get txnErrAmount => 'Enter an amount';

  @override
  String get txnErrAmountInvalid => 'This calculation is not valid';

  @override
  String get txnErrDivZero => 'Division by zero';

  @override
  String get txnErrTooLarge => 'This amount is too large';

  @override
  String get txnErrRequired => 'Required';

  @override
  String get txnErrSameAccount => 'Choose two different accounts';

  @override
  String get txnErrSplit => 'The split lines must add up to the total';

  @override
  String get txnErrNoAccount =>
      'Create an account first to record transactions.';

  @override
  String get txnErrCheckFields => 'Please check the highlighted fields.';

  @override
  String get txnCreateAccount => 'Create account';

  @override
  String get txnSavedExpense => 'Expense saved';

  @override
  String get txnSavedIncome => 'Income saved';

  @override
  String get txnSavedTransfer => 'Transfer saved';

  @override
  String get txnChangesSaved => 'Changes saved';

  @override
  String txnSaveFailed(String message) {
    return 'Could not save: $message';
  }

  @override
  String get txnAddSplit => 'Add split';

  @override
  String txnRemaining(String amount) {
    return 'Remaining $amount';
  }

  @override
  String txnOverAssigned(String amount) {
    return 'Over by $amount';
  }

  @override
  String get txnFullyAssigned => 'Fully assigned';

  @override
  String get txnRemoveSplit => 'Remove line';

  @override
  String txnSplitLineCategory(int n) {
    return 'Split $n category';
  }

  @override
  String txnSplitLineAmount(int n) {
    return 'Split $n amount';
  }

  @override
  String get txnAssignRemaining => 'Assign remaining';

  @override
  String get txnStopSplit => 'Remove split';

  @override
  String get txnAddTag => 'Add tag';

  @override
  String txnRemoveTag(String name) {
    return 'Remove tag $name';
  }

  @override
  String txnCreateTag(String name) {
    return 'Create “$name”';
  }

  @override
  String get txnSearchTags => 'Search or create a tag';

  @override
  String get txnMoreDetails => 'More details';

  @override
  String txnUseTemplate(String name) {
    return 'Use template $name';
  }

  @override
  String get txnTemplatesEmpty =>
      'No templates yet. Save a transaction as a template to enter it with one tap.';

  @override
  String get txnTemplateAddNow => 'Add now';

  @override
  String txnTemplatePosted(String name) {
    return '$name added';
  }

  @override
  String get txnTemplateName => 'Template name';

  @override
  String get txnTemplateDeleted => 'Template deleted';

  @override
  String get txnTemplateFillIn => 'Open in quick add';

  @override
  String get txnTemplateInvalid =>
      'This template is incomplete. Edit it to choose an account.';

  @override
  String get txnPickDate => 'Choose date';

  @override
  String get txnClear => 'Clear';

  @override
  String txnSum(String amount) {
    return 'Total $amount';
  }

  @override
  String get txnKeyDelete => 'Del';

  @override
  String get txnImportBatchChip => 'From one import';

  @override
  String get txnCreateRule => 'Create rule';
}
