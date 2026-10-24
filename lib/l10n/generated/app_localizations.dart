import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @accountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTitle;

  /// No description provided for @accountsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accountsAdd;

  /// No description provided for @accountsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet. Add your bank accounts, cash and cards to track balances and net worth.'**
  String get accountsEmpty;

  /// No description provided for @accountsReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder accounts'**
  String get accountsReorder;

  /// No description provided for @accountsReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Drag accounts to change their order, or below another heading to move them into that group.'**
  String get accountsReorderHint;

  /// No description provided for @accountsDragHandle.
  ///
  /// In en, this message translates to:
  /// **'Move {name}'**
  String accountsDragHandle(String name);

  /// No description provided for @accountsReconcileBalances.
  ///
  /// In en, this message translates to:
  /// **'Reconcile balances'**
  String get accountsReconcileBalances;

  /// No description provided for @accountsSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select an account to see its details.'**
  String get accountsSelectHint;

  /// No description provided for @accountsMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get accountsMoreActions;

  /// No description provided for @accountsManageGroups.
  ///
  /// In en, this message translates to:
  /// **'Manage groups'**
  String get accountsManageGroups;

  /// No description provided for @accountsShowArchivedMenu.
  ///
  /// In en, this message translates to:
  /// **'Show archived accounts'**
  String get accountsShowArchivedMenu;

  /// No description provided for @accountsHideArchived.
  ///
  /// In en, this message translates to:
  /// **'Hide archived accounts'**
  String get accountsHideArchived;

  /// No description provided for @accountsShowArchived.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 archived account} other{Show {count} archived accounts}}'**
  String accountsShowArchived(int count);

  /// No description provided for @accountsArchivedSection.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get accountsArchivedSection;

  /// No description provided for @accountsArchivedDesc.
  ///
  /// In en, this message translates to:
  /// **'Hidden from lists and pickers. Its history stays.'**
  String get accountsArchivedDesc;

  /// No description provided for @accountsNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get accountsNetWorth;

  /// No description provided for @accountsAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get accountsAssets;

  /// No description provided for @accountsLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get accountsLiabilities;

  /// No description provided for @accountsNetWorthSemantics.
  ///
  /// In en, this message translates to:
  /// **'Net worth {net}. Assets {assets}, liabilities {liabilities}.'**
  String accountsNetWorthSemantics(
    String net,
    String assets,
    String liabilities,
  );

  /// No description provided for @accountsAlertBelow.
  ///
  /// In en, this message translates to:
  /// **'Alert below {amount}'**
  String accountsAlertBelow(String amount);

  /// No description provided for @accountsBelowThreshold.
  ///
  /// In en, this message translates to:
  /// **'Below the {amount} alert'**
  String accountsBelowThreshold(String amount);

  /// No description provided for @accountsNotInNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Not in net worth'**
  String get accountsNotInNetWorth;

  /// No description provided for @accountsNotInBudgets.
  ///
  /// In en, this message translates to:
  /// **'Not in budgets'**
  String get accountsNotInBudgets;

  /// No description provided for @accountsNotInForecast.
  ///
  /// In en, this message translates to:
  /// **'Not in forecast'**
  String get accountsNotInForecast;

  /// No description provided for @accountsReturnAssumed.
  ///
  /// In en, this message translates to:
  /// **'{rate} p.a. assumed'**
  String accountsReturnAssumed(String rate);

  /// No description provided for @accountsInterestRate.
  ///
  /// In en, this message translates to:
  /// **'{rate} interest'**
  String accountsInterestRate(String rate);

  /// No description provided for @accountsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get accountsOpen;

  /// No description provided for @accountsReconcile.
  ///
  /// In en, this message translates to:
  /// **'Reconcile'**
  String get accountsReconcile;

  /// No description provided for @accountsArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get accountsArchive;

  /// No description provided for @accountsUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get accountsUnarchive;

  /// No description provided for @accountsNoGroup.
  ///
  /// In en, this message translates to:
  /// **'No group'**
  String get accountsNoGroup;

  /// No description provided for @accountsTypeChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get accountsTypeChecking;

  /// No description provided for @accountsTypeSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get accountsTypeSavings;

  /// No description provided for @accountsTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountsTypeCash;

  /// No description provided for @accountsTypeCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get accountsTypeCreditCard;

  /// No description provided for @accountsTypeInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get accountsTypeInvestment;

  /// No description provided for @accountsTypeLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get accountsTypeLoan;

  /// No description provided for @accountsTypeOtherAsset.
  ///
  /// In en, this message translates to:
  /// **'Other asset'**
  String get accountsTypeOtherAsset;

  /// No description provided for @accountsTypeOtherLiability.
  ///
  /// In en, this message translates to:
  /// **'Other liability'**
  String get accountsTypeOtherLiability;

  /// No description provided for @accountsArchivedSnack.
  ///
  /// In en, this message translates to:
  /// **'Account archived'**
  String get accountsArchivedSnack;

  /// No description provided for @accountsUnarchivedSnack.
  ///
  /// In en, this message translates to:
  /// **'Account restored'**
  String get accountsUnarchivedSnack;

  /// No description provided for @accountsCannotDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Account in use'**
  String get accountsCannotDeleteTitle;

  /// No description provided for @accountsDeleteInUse.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This account has 1 transaction and can\'t be deleted. Archive it to hide it while keeping its history.} other{This account has {count} transactions and can\'t be deleted. Archive it to hide it while keeping its history.}}'**
  String accountsDeleteInUse(int count);

  /// No description provided for @accountsDeleteInUseRules.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{A recurring rule uses this account. Change or delete it first, or archive the account.} other{{count} recurring rules use this account. Change or delete them first, or archive the account.}}'**
  String accountsDeleteInUseRules(int count);

  /// No description provided for @accountsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'The account has no transactions. Linked goals are unlinked.'**
  String get accountsDeleteMessage;

  /// No description provided for @accountsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountsDeleted;

  /// No description provided for @accountsNotFound.
  ///
  /// In en, this message translates to:
  /// **'This account no longer exists.'**
  String get accountsNotFound;

  /// No description provided for @accountsRange1M.
  ///
  /// In en, this message translates to:
  /// **'1M'**
  String get accountsRange1M;

  /// No description provided for @accountsRange3M.
  ///
  /// In en, this message translates to:
  /// **'3M'**
  String get accountsRange3M;

  /// No description provided for @accountsRange6M.
  ///
  /// In en, this message translates to:
  /// **'6M'**
  String get accountsRange6M;

  /// No description provided for @accountsRange1Y.
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get accountsRange1Y;

  /// No description provided for @accountsRangeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get accountsRangeAll;

  /// No description provided for @accountsCurrentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current balance'**
  String get accountsCurrentBalance;

  /// No description provided for @accountsLowBalanceWarning.
  ///
  /// In en, this message translates to:
  /// **'Below the low-balance alert of {amount}'**
  String accountsLowBalanceWarning(String amount);

  /// No description provided for @accountsBalanceOverTime.
  ///
  /// In en, this message translates to:
  /// **'Balance over time'**
  String get accountsBalanceOverTime;

  /// No description provided for @accountsChartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not enough data for a chart yet.'**
  String get accountsChartEmpty;

  /// No description provided for @accountsChartSemantics.
  ///
  /// In en, this message translates to:
  /// **'Balance of {name} from {from} to {to}: {start} at the start, {end} at the end, lowest {lowest}.'**
  String accountsChartSemantics(
    String name,
    String from,
    String to,
    String start,
    String end,
    String lowest,
  );

  /// No description provided for @accountsRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get accountsRecentTransactions;

  /// No description provided for @accountsAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get accountsAllTransactions;

  /// No description provided for @accountsNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this account yet.'**
  String get accountsNoTransactions;

  /// No description provided for @accountsDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get accountsDetails;

  /// No description provided for @accountsTransferWith.
  ///
  /// In en, this message translates to:
  /// **'Transfer · {name}'**
  String accountsTransferWith(String name);

  /// No description provided for @accountsSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get accountsSplit;

  /// No description provided for @accountsUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorised'**
  String get accountsUncategorized;

  /// No description provided for @accountsNew.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get accountsNew;

  /// No description provided for @accountsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get accountsEditTitle;

  /// No description provided for @accountsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get accountsCreate;

  /// No description provided for @accountsSectionBasics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get accountsSectionBasics;

  /// No description provided for @accountsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get accountsSectionAppearance;

  /// No description provided for @accountsSectionInclude.
  ///
  /// In en, this message translates to:
  /// **'Counts toward'**
  String get accountsSectionInclude;

  /// No description provided for @accountsSectionPlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get accountsSectionPlanning;

  /// No description provided for @accountsFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountsFieldName;

  /// No description provided for @accountsNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get accountsNameRequired;

  /// No description provided for @accountsFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get accountsFieldType;

  /// No description provided for @accountsFieldOpeningBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get accountsFieldOpeningBalance;

  /// No description provided for @accountsFieldOpeningDate.
  ///
  /// In en, this message translates to:
  /// **'Opening date'**
  String get accountsFieldOpeningDate;

  /// No description provided for @accountsLiabilityHint.
  ///
  /// In en, this message translates to:
  /// **'Enter debt as a negative amount, e.g. −4,152.30.'**
  String get accountsLiabilityHint;

  /// No description provided for @accountsFieldGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get accountsFieldGroup;

  /// No description provided for @accountsNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New group…'**
  String get accountsNewGroup;

  /// No description provided for @accountsGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get accountsGroupName;

  /// No description provided for @accountsIncludeNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get accountsIncludeNetWorth;

  /// No description provided for @accountsIncludeBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get accountsIncludeBudgets;

  /// No description provided for @accountsIncludeBudgetsDesc.
  ///
  /// In en, this message translates to:
  /// **'Spending from this account counts against budgets'**
  String get accountsIncludeBudgetsDesc;

  /// No description provided for @accountsIncludeForecast.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get accountsIncludeForecast;

  /// No description provided for @accountsLowBalance.
  ///
  /// In en, this message translates to:
  /// **'Low-balance alert'**
  String get accountsLowBalance;

  /// No description provided for @accountsLowBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'Warn when the balance falls below this amount'**
  String get accountsLowBalanceHint;

  /// No description provided for @accountsExpectedReturn.
  ///
  /// In en, this message translates to:
  /// **'Expected annual return'**
  String get accountsExpectedReturn;

  /// No description provided for @accountsExpectedReturnHint.
  ///
  /// In en, this message translates to:
  /// **'Used by the net-worth projection'**
  String get accountsExpectedReturnHint;

  /// No description provided for @accountsInterest.
  ///
  /// In en, this message translates to:
  /// **'Interest rate'**
  String get accountsInterest;

  /// No description provided for @accountsInterestHint.
  ///
  /// In en, this message translates to:
  /// **'Annual rate, e.g. for loans and credit cards'**
  String get accountsInterestHint;

  /// No description provided for @accountsRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a percentage between −100 and 100'**
  String get accountsRateInvalid;

  /// No description provided for @accountsNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get accountsNote;

  /// No description provided for @accountsDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get accountsDiscardTitle;

  /// No description provided for @accountsKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get accountsKeepEditing;

  /// No description provided for @accountsDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get accountsDiscard;

  /// No description provided for @accountsReconcileTitle.
  ///
  /// In en, this message translates to:
  /// **'Reconcile'**
  String get accountsReconcileTitle;

  /// No description provided for @accountsReconcileIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the balance your bank shows for the date below. The cleared transactions in the app should add up to it.'**
  String get accountsReconcileIntro;

  /// No description provided for @accountsBankBalance.
  ///
  /// In en, this message translates to:
  /// **'Bank balance'**
  String get accountsBankBalance;

  /// No description provided for @accountsBankDate.
  ///
  /// In en, this message translates to:
  /// **'Balance date'**
  String get accountsBankDate;

  /// No description provided for @accountsDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get accountsDifference;

  /// No description provided for @accountsClearedBalance.
  ///
  /// In en, this message translates to:
  /// **'Cleared in the app'**
  String get accountsClearedBalance;

  /// No description provided for @accountsPendingSum.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Pending} =1{Pending (1)} other{Pending ({count})}}'**
  String accountsPendingSum(int count);

  /// No description provided for @accountsEnterBankBalance.
  ///
  /// In en, this message translates to:
  /// **'Enter the bank balance to compare.'**
  String get accountsEnterBankBalance;

  /// No description provided for @accountsReconciled.
  ///
  /// In en, this message translates to:
  /// **'Balanced. The app matches your bank.'**
  String get accountsReconciled;

  /// No description provided for @accountsDifferenceMore.
  ///
  /// In en, this message translates to:
  /// **'Your bank shows more than the app. Clear pending income or add the missing entries.'**
  String get accountsDifferenceMore;

  /// No description provided for @accountsDifferenceLess.
  ///
  /// In en, this message translates to:
  /// **'Your bank shows less than the app. Clear pending expenses the bank already booked.'**
  String get accountsDifferenceLess;

  /// No description provided for @accountsCreateCorrection.
  ///
  /// In en, this message translates to:
  /// **'Book correction of {amount}'**
  String accountsCreateCorrection(String amount);

  /// No description provided for @accountsCreateCorrectionShort.
  ///
  /// In en, this message translates to:
  /// **'Book correction'**
  String get accountsCreateCorrectionShort;

  /// No description provided for @accountsCorrectionConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Book a correction?'**
  String get accountsCorrectionConfirmTitle;

  /// No description provided for @accountsCorrectionConfirm.
  ///
  /// In en, this message translates to:
  /// **'A cleared transaction of {amount} is added so the app matches the bank balance.'**
  String accountsCorrectionConfirm(String amount);

  /// No description provided for @accountsCorrectionPayee.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation'**
  String get accountsCorrectionPayee;

  /// No description provided for @accountsCorrectionNote.
  ///
  /// In en, this message translates to:
  /// **'Correction to match the bank balance'**
  String get accountsCorrectionNote;

  /// No description provided for @accountsCorrectionCreated.
  ///
  /// In en, this message translates to:
  /// **'Correction booked'**
  String get accountsCorrectionCreated;

  /// No description provided for @accountsPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending transactions'**
  String get accountsPendingTitle;

  /// No description provided for @accountsPendingHint.
  ///
  /// In en, this message translates to:
  /// **'Select the ones your bank already booked and mark them as cleared.'**
  String get accountsPendingHint;

  /// No description provided for @accountsNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending transactions up to this date.'**
  String get accountsNoPending;

  /// No description provided for @accountsSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get accountsSelectAll;

  /// No description provided for @accountsMarkClearedNone.
  ///
  /// In en, this message translates to:
  /// **'Mark as cleared'**
  String get accountsMarkClearedNone;

  /// No description provided for @accountsMarkCleared.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Mark 1 as cleared ({amount})} other{Mark {count} as cleared ({amount})}}'**
  String accountsMarkCleared(int count, String amount);

  /// No description provided for @accountsMarkedCleared.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction cleared} other{{count} transactions cleared}}'**
  String accountsMarkedCleared(int count);

  /// No description provided for @accountsGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Account groups'**
  String get accountsGroupsTitle;

  /// No description provided for @accountsGroupsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No groups yet. Groups bundle accounts in the list, e.g. \"Daily\" or \"Savings\".'**
  String get accountsGroupsEmpty;

  /// No description provided for @accountsGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to rename, drag to reorder. Deleting a group keeps its accounts.'**
  String get accountsGroupsHint;

  /// No description provided for @accountsGroupAdd.
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get accountsGroupAdd;

  /// No description provided for @accountsGroupRename.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get accountsGroupRename;

  /// No description provided for @accountsGroupDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Its accounts stay and become ungrouped.'**
  String get accountsGroupDeleteMessage;

  /// No description provided for @accountsGroupDeleted.
  ///
  /// In en, this message translates to:
  /// **'Group deleted'**
  String get accountsGroupDeleted;

  /// No description provided for @accountsGroupCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No accounts} =1{1 account} other{{count} accounts}}'**
  String accountsGroupCount(int count);

  /// No description provided for @backupBootTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data could not be opened'**
  String get backupBootTitle;

  /// No description provided for @backupBootMissingKey.
  ///
  /// In en, this message translates to:
  /// **'The key that unlocks the database is missing on this device. This happens when app data is copied to a new device or restored without the device\'s secure storage.'**
  String get backupBootMissingKey;

  /// No description provided for @backupBootNewer.
  ///
  /// In en, this message translates to:
  /// **'The database was created by a newer version of the app. Install the latest version to open it.'**
  String get backupBootNewer;

  /// No description provided for @backupBootGeneric.
  ///
  /// In en, this message translates to:
  /// **'The app could not start. This can be temporary, for example when storage is full or the device is still locked. Try again; the database file was not changed.'**
  String get backupBootGeneric;

  /// No description provided for @backupBootKept.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been deleted. The database file stays on this device.'**
  String get backupBootKept;

  /// No description provided for @backupBootDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get backupBootDetails;

  /// No description provided for @backupBootStartFresh.
  ///
  /// In en, this message translates to:
  /// **'Start with an empty database'**
  String get backupBootStartFresh;

  /// No description provided for @backupBootStartFreshConfirm.
  ///
  /// In en, this message translates to:
  /// **'The current database file is moved to a separate folder, not deleted. The app then starts empty, and you can restore a backup under More › Export & backup.'**
  String get backupBootStartFreshConfirm;

  /// No description provided for @backupBootMoved.
  ///
  /// In en, this message translates to:
  /// **'The old database file was moved to:\n{path}'**
  String backupBootMoved(String path);

  /// No description provided for @backupMissingReceipts.
  ///
  /// In en, this message translates to:
  /// **'Backup saved. {count} receipt files were already missing on this device and are not in it.'**
  String backupMissingReceipts(int count);

  /// No description provided for @backupReceipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get backupReceipts;

  /// No description provided for @backupReceiptsValue.
  ///
  /// In en, this message translates to:
  /// **'{count} files, {size}'**
  String backupReceiptsValue(int count, String size);

  /// No description provided for @backupRestoreMissing.
  ///
  /// In en, this message translates to:
  /// **'{count} receipt files were already missing when this backup was made and cannot be restored.'**
  String backupRestoreMissing(int count);

  /// No description provided for @backupChannel.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get backupChannel;

  /// No description provided for @backupHealthBackUp.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupHealthBackUp;

  /// No description provided for @backupHealthDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get backupHealthDetails;

  /// No description provided for @backupHealthFailing.
  ///
  /// In en, this message translates to:
  /// **'The automatic backup failed: {message}'**
  String backupHealthFailing(String message);

  /// No description provided for @backupHealthInterrupted.
  ///
  /// In en, this message translates to:
  /// **'The last automatic backup did not finish.'**
  String get backupHealthInterrupted;

  /// No description provided for @backupHealthNever.
  ///
  /// In en, this message translates to:
  /// **'Your data has not been backed up yet.'**
  String get backupHealthNever;

  /// No description provided for @backupHealthStale.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {date}. Back up again so recent changes are safe.'**
  String backupHealthStale(String date);

  /// No description provided for @backupNotifyFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup failed'**
  String get backupNotifyFailedTitle;

  /// No description provided for @backupNotifyFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Your automatic backup could not be written. Open the app to fix it.'**
  String get backupNotifyFailedBody;

  /// No description provided for @backupResetKeepCopy.
  ///
  /// In en, this message translates to:
  /// **'Keep a safety copy on this device'**
  String get backupResetKeepCopy;

  /// No description provided for @backupResetKeepCopyDesc.
  ///
  /// In en, this message translates to:
  /// **'Lets you undo the reset under More › Export & backup › Safety copies. Untick to also delete the safety copies.'**
  String get backupResetKeepCopyDesc;

  /// No description provided for @backupSafetyActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get backupSafetyActions;

  /// No description provided for @backupSafetyDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get backupSafetyDelete;

  /// No description provided for @backupSafetyDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete the safety copy from {date}?'**
  String backupSafetyDeleteConfirm(String date);

  /// No description provided for @backupSafetyDesc.
  ///
  /// In en, this message translates to:
  /// **'Taken automatically before a restore, a reset, undoing an import, merging categories or tags and removing old deleted entries. They stay on this device and hold all data except receipt files, which these actions never delete. The newest 10 are kept.'**
  String get backupSafetyDesc;

  /// No description provided for @backupSafetyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No safety copies yet.'**
  String get backupSafetyEmpty;

  /// No description provided for @backupSafetyFailed.
  ///
  /// In en, this message translates to:
  /// **'No safety copy could be taken, so nothing was changed: {message}'**
  String backupSafetyFailed(String message);

  /// No description provided for @backupSafetyReasonImportUndo.
  ///
  /// In en, this message translates to:
  /// **'Before undoing an import'**
  String get backupSafetyReasonImportUndo;

  /// No description provided for @backupSafetyReasonMerge.
  ///
  /// In en, this message translates to:
  /// **'Before merging'**
  String get backupSafetyReasonMerge;

  /// No description provided for @backupSafetyReasonPurge.
  ///
  /// In en, this message translates to:
  /// **'Before removing old deleted entries'**
  String get backupSafetyReasonPurge;

  /// No description provided for @backupSafetyReasonReset.
  ///
  /// In en, this message translates to:
  /// **'Before resetting the app'**
  String get backupSafetyReasonReset;

  /// No description provided for @backupSafetyReasonRestore.
  ///
  /// In en, this message translates to:
  /// **'Before restoring a backup'**
  String get backupSafetyReasonRestore;

  /// No description provided for @backupSafetyReasonRestoreCopy.
  ///
  /// In en, this message translates to:
  /// **'Before restoring a safety copy'**
  String get backupSafetyReasonRestoreCopy;

  /// No description provided for @backupSafetyRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupSafetyRestore;

  /// No description provided for @backupSafetyRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Replace all current data with the safety copy from {date}? A safety copy of the current data is taken first, so you can go back.'**
  String backupSafetyRestoreConfirm(String date);

  /// No description provided for @backupSafetyRestored.
  ///
  /// In en, this message translates to:
  /// **'Safety copy restored ({count} rows)'**
  String backupSafetyRestored(int count);

  /// No description provided for @backupSafetyRows.
  ///
  /// In en, this message translates to:
  /// **'{rows} rows · {size}'**
  String backupSafetyRows(String rows, String size);

  /// No description provided for @backupSafetySave.
  ///
  /// In en, this message translates to:
  /// **'Save elsewhere'**
  String get backupSafetySave;

  /// No description provided for @backupSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety copies'**
  String get backupSafetyTitle;

  /// No description provided for @backupStaleDays.
  ///
  /// In en, this message translates to:
  /// **'Warn when the last backup is older than'**
  String get backupStaleDays;

  /// No description provided for @backupStaleDaysValue.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String backupStaleDaysValue(int days);

  /// No description provided for @backupFolderAccessLost.
  ///
  /// In en, this message translates to:
  /// **'The app no longer has access to the backup folder. Choose the folder again.'**
  String get backupFolderAccessLost;

  /// No description provided for @backupUseAppDocuments.
  ///
  /// In en, this message translates to:
  /// **'Use “On My iPhone” in Files'**
  String get backupUseAppDocuments;

  /// No description provided for @backupErrDamaged.
  ///
  /// In en, this message translates to:
  /// **'The backup file is damaged or was changed. It cannot be restored.'**
  String get backupErrDamaged;

  /// No description provided for @backupHealthCheckPassword.
  ///
  /// In en, this message translates to:
  /// **'Do you still know your backup password? Type it once to make sure.'**
  String get backupHealthCheckPassword;

  /// No description provided for @backupPasswordChange.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get backupPasswordChange;

  /// No description provided for @backupPasswordCheck.
  ///
  /// In en, this message translates to:
  /// **'Check password'**
  String get backupPasswordCheck;

  /// No description provided for @backupPasswordCorrect.
  ///
  /// In en, this message translates to:
  /// **'That\'s right. Your backup password is confirmed.'**
  String get backupPasswordCorrect;

  /// No description provided for @backupPasswordDesc.
  ///
  /// In en, this message translates to:
  /// **'Backups that leave this device are encrypted with a password you choose. Anyone without the password or the recovery key sees only scrambled data, and so would you: keep both somewhere safe.'**
  String get backupPasswordDesc;

  /// No description provided for @backupPasswordField.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPasswordField;

  /// No description provided for @backupPasswordFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get backupPasswordFinish;

  /// No description provided for @backupPasswordHide.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get backupPasswordHide;

  /// No description provided for @backupPasswordLastChecked.
  ///
  /// In en, this message translates to:
  /// **'Last confirmed on {date}'**
  String backupPasswordLastChecked(String date);

  /// No description provided for @backupPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least {count} characters'**
  String backupPasswordMinLength(int count);

  /// No description provided for @backupPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match'**
  String get backupPasswordMismatch;

  /// No description provided for @backupPasswordNewRecovery.
  ///
  /// In en, this message translates to:
  /// **'New recovery key'**
  String get backupPasswordNewRecovery;

  /// No description provided for @backupPasswordOn.
  ///
  /// In en, this message translates to:
  /// **'Backups are encrypted'**
  String get backupPasswordOn;

  /// No description provided for @backupPasswordRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat the password'**
  String get backupPasswordRepeat;

  /// No description provided for @backupPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'Set backup password'**
  String get backupPasswordSet;

  /// No description provided for @backupPasswordShow.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get backupPasswordShow;

  /// No description provided for @backupPasswordSince.
  ///
  /// In en, this message translates to:
  /// **'Password set on {date}'**
  String backupPasswordSince(String date);

  /// No description provided for @backupPasswordStepIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose a password for your backups. It is different from the app lock and is needed to restore a backup on another device.'**
  String get backupPasswordStepIntro;

  /// No description provided for @backupPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPasswordTitle;

  /// No description provided for @backupPasswordWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get backupPasswordWrong;

  /// No description provided for @backupPasswordWrongDesc.
  ///
  /// In en, this message translates to:
  /// **'That is not the backup password. If you no longer know it, set a new one now: new backups use it, and older ones still open with the old password or the recovery key.'**
  String get backupPasswordWrongDesc;

  /// No description provided for @backupRecoveryConfirmIntro.
  ///
  /// In en, this message translates to:
  /// **'To make sure you have the recovery key, type two of its groups.'**
  String get backupRecoveryConfirmIntro;

  /// No description provided for @backupRecoveryCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get backupRecoveryCopy;

  /// No description provided for @backupRecoveryFileIntro.
  ///
  /// In en, this message translates to:
  /// **'Recovery key for the backups of Quiet Ledger. Anyone with this key can open your backups; keep it private and safe.'**
  String get backupRecoveryFileIntro;

  /// No description provided for @backupRecoveryGroup.
  ///
  /// In en, this message translates to:
  /// **'Group {number}'**
  String backupRecoveryGroup(int number);

  /// No description provided for @backupRecoveryIntro.
  ///
  /// In en, this message translates to:
  /// **'This is your recovery key. It opens your backups if you forget the password. Write it down or save it outside this device, e.g. in a password manager.'**
  String get backupRecoveryIntro;

  /// No description provided for @backupRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get backupRecoveryKey;

  /// No description provided for @backupRecoverySave.
  ///
  /// In en, this message translates to:
  /// **'Save as file'**
  String get backupRecoverySave;

  /// No description provided for @backupRecoveryShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Show the recovery key again'**
  String get backupRecoveryShowAgain;

  /// No description provided for @backupRecoveryStored.
  ///
  /// In en, this message translates to:
  /// **'I have stored the recovery key in a safe place'**
  String get backupRecoveryStored;

  /// No description provided for @backupRecoveryWarning.
  ///
  /// In en, this message translates to:
  /// **'It is shown only now. Without the password and the recovery key, your encrypted backups cannot be opened by anyone.'**
  String get backupRecoveryWarning;

  /// No description provided for @backupUnlockDesc.
  ///
  /// In en, this message translates to:
  /// **'This backup is encrypted. Enter its backup password or the recovery key.'**
  String get backupUnlockDesc;

  /// No description provided for @backupUnlockOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get backupUnlockOpen;

  /// No description provided for @backupUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup'**
  String get backupUnlockTitle;

  /// No description provided for @backupUnlockWrong.
  ///
  /// In en, this message translates to:
  /// **'That does not open this backup. Try again.'**
  String get backupUnlockWrong;

  /// No description provided for @backupCheck.
  ///
  /// In en, this message translates to:
  /// **'Check a backup'**
  String get backupCheck;

  /// No description provided for @backupCheckOk.
  ///
  /// In en, this message translates to:
  /// **'Backup is complete'**
  String get backupCheckOk;

  /// No description provided for @backupCheckOkDesc.
  ///
  /// In en, this message translates to:
  /// **'{file}\nMade on {date}. All checksums match: {rows} rows and {files} receipt files can be restored.'**
  String backupCheckOkDesc(String file, String date, int rows, int files);

  /// No description provided for @backupFolderFileGone.
  ///
  /// In en, this message translates to:
  /// **'The backup is no longer in the folder.'**
  String get backupFolderFileGone;

  /// No description provided for @backupFolderList.
  ///
  /// In en, this message translates to:
  /// **'Backups in the folder'**
  String get backupFolderList;

  /// No description provided for @backupFolderListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No backups in this folder yet.'**
  String get backupFolderListEmpty;

  /// No description provided for @backupRestoreNewer.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change on this device is newer than this backup and will be replaced (it stays in the safety copy).} other{{count} changes on this device are newer than this backup and will be replaced (they stay in the safety copy).}}'**
  String backupRestoreNewer(int count);

  /// No description provided for @backupWebStorageNotPersistent.
  ///
  /// In en, this message translates to:
  /// **'This browser may clear the app\'s data when space runs low. Back up regularly.'**
  String get backupWebStorageNotPersistent;

  /// No description provided for @backupWebStoragePersistent.
  ///
  /// In en, this message translates to:
  /// **'This browser keeps the app\'s data and does not clear it on its own.'**
  String get backupWebStoragePersistent;

  /// No description provided for @backupBootUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The database file is damaged or cannot be unlocked with the key on this device.'**
  String get backupBootUnreadable;

  /// No description provided for @backupBootCopyDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy details'**
  String get backupBootCopyDetails;

  /// No description provided for @backupAppDocumentsFolder.
  ///
  /// In en, this message translates to:
  /// **'On My iPhone › Quiet Ledger › Backups'**
  String get backupAppDocumentsFolder;

  /// No description provided for @backupFolderMissing.
  ///
  /// In en, this message translates to:
  /// **'The backup folder was not found. Connect the drive it is on, or choose the folder again.'**
  String get backupFolderMissing;

  /// No description provided for @backupUnencryptedWarning.
  ///
  /// In en, this message translates to:
  /// **'Backups are not encrypted. Anyone who gets a backup file can read all your financial data.'**
  String get backupUnencryptedWarning;

  /// No description provided for @backupSavedUnencrypted.
  ///
  /// In en, this message translates to:
  /// **'Not encrypted: anyone who has the file can read it.'**
  String get backupSavedUnencrypted;

  /// No description provided for @budgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgetsTitle;

  /// No description provided for @budgetsBudgeted.
  ///
  /// In en, this message translates to:
  /// **'Budgeted'**
  String get budgetsBudgeted;

  /// No description provided for @budgetsSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get budgetsSpent;

  /// No description provided for @budgetsLeftLabel.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get budgetsLeftLabel;

  /// No description provided for @budgetsLeftDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Left · last day} =1{Left · 1 day} other{Left · {days} days}}'**
  String budgetsLeftDays(int days);

  /// No description provided for @budgetsTodayDayOf.
  ///
  /// In en, this message translates to:
  /// **'Today, day {day} of {total}'**
  String budgetsTodayDayOf(int day, int total);

  /// No description provided for @budgetsOfAmount.
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String budgetsOfAmount(String amount);

  /// No description provided for @budgetsOverBudget.
  ///
  /// In en, this message translates to:
  /// **'{amount} over budget'**
  String budgetsOverBudget(String amount);

  /// No description provided for @budgetsUsedLeft.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used · {amount} left'**
  String budgetsUsedLeft(int percent, String amount);

  /// No description provided for @budgetsAmountLeft.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String budgetsAmountLeft(String amount);

  /// No description provided for @budgetsInclRolledOver.
  ///
  /// In en, this message translates to:
  /// **'incl. {amount} rolled over'**
  String budgetsInclRolledOver(String amount);

  /// No description provided for @budgetsInclOverspentCarried.
  ///
  /// In en, this message translates to:
  /// **'incl. {amount} overspent carried over'**
  String budgetsInclOverspentCarried(String amount);

  /// No description provided for @budgetsSpentOf.
  ///
  /// In en, this message translates to:
  /// **'{spent} spent of {available}'**
  String budgetsSpentOf(String spent, String available);

  /// No description provided for @budgetsUnbudgetedSpent.
  ///
  /// In en, this message translates to:
  /// **'{amount} spent in categories without a budget'**
  String budgetsUnbudgetedSpent(String amount);

  /// No description provided for @budgetsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No budgets for this period yet.'**
  String get budgetsEmpty;

  /// No description provided for @budgetsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add budget'**
  String get budgetsAdd;

  /// No description provided for @budgetsCopyPrevious.
  ///
  /// In en, this message translates to:
  /// **'Copy previous period'**
  String get budgetsCopyPrevious;

  /// No description provided for @budgetsFromAverage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{From last period’s spending} other{From {count}-period average}}'**
  String budgetsFromAverage(int count);

  /// No description provided for @budgetsFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'From template'**
  String get budgetsFromTemplate;

  /// No description provided for @budgetsSaveTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as template'**
  String get budgetsSaveTemplate;

  /// No description provided for @budgetsEditAll.
  ///
  /// In en, this message translates to:
  /// **'Edit all amounts'**
  String get budgetsEditAll;

  /// No description provided for @budgetsClearPeriod.
  ///
  /// In en, this message translates to:
  /// **'Remove all budgets'**
  String get budgetsClearPeriod;

  /// No description provided for @budgetsClearPeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove all budgets of this period?'**
  String get budgetsClearPeriodTitle;

  /// No description provided for @budgetsClearPeriodMessage.
  ///
  /// In en, this message translates to:
  /// **'Transactions are not affected.'**
  String get budgetsClearPeriodMessage;

  /// No description provided for @budgetsFillMenu.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get budgetsFillMenu;

  /// No description provided for @budgetsFilledCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No budgets set} =1{1 budget set} other{{count} budgets set}}'**
  String budgetsFilledCount(int count);

  /// No description provided for @budgetsNothingToCopy.
  ///
  /// In en, this message translates to:
  /// **'The previous period has no budgets.'**
  String get budgetsNothingToCopy;

  /// No description provided for @budgetsNoSpendingHistory.
  ///
  /// In en, this message translates to:
  /// **'No spending found in those periods.'**
  String get budgetsNoSpendingHistory;

  /// No description provided for @budgetsOverwriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace existing amounts?'**
  String get budgetsOverwriteTitle;

  /// No description provided for @budgetsOverwriteMessage.
  ///
  /// In en, this message translates to:
  /// **'Categories that already have a budget in this period get the new amount; others stay unchanged.'**
  String get budgetsOverwriteMessage;

  /// No description provided for @budgetsOverwriteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get budgetsOverwriteConfirm;

  /// No description provided for @budgetsAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetsAmountLabel;

  /// No description provided for @budgetsAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount of 0 or more'**
  String get budgetsAmountInvalid;

  /// No description provided for @budgetsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove budget'**
  String get budgetsRemove;

  /// No description provided for @budgetsTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get budgetsTemplateName;

  /// No description provided for @budgetsTemplateNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get budgetsTemplateNameRequired;

  /// No description provided for @budgetsTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template “{name}” saved'**
  String budgetsTemplateSaved(String name);

  /// No description provided for @budgetsTemplateSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category} other{{count} categories}} · {total}'**
  String budgetsTemplateSummary(int count, String total);

  /// No description provided for @budgetsNoTemplates.
  ///
  /// In en, this message translates to:
  /// **'No templates yet. Save a period as a template first.'**
  String get budgetsNoTemplates;

  /// No description provided for @budgetsBulkTotal.
  ///
  /// In en, this message translates to:
  /// **'Total budgeted: {amount}'**
  String budgetsBulkTotal(String amount);

  /// No description provided for @budgetsNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No expense categories yet.'**
  String get budgetsNoCategories;

  /// No description provided for @budgetsLeftToAssign.
  ///
  /// In en, this message translates to:
  /// **'{amount} left to assign'**
  String budgetsLeftToAssign(String amount);

  /// No description provided for @budgetsAllAssigned.
  ///
  /// In en, this message translates to:
  /// **'Every euro is assigned'**
  String get budgetsAllAssigned;

  /// No description provided for @budgetsOverAssigned.
  ///
  /// In en, this message translates to:
  /// **'{amount} more assigned than available'**
  String budgetsOverAssigned(String amount);

  /// No description provided for @budgetsEnvelopeFormula.
  ///
  /// In en, this message translates to:
  /// **'Income {income} + carried over {carry} − assigned {assigned}'**
  String budgetsEnvelopeFormula(String income, String carry, String assigned);

  /// No description provided for @budgetsSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select a budget to see its details.'**
  String get budgetsSelectHint;

  /// No description provided for @budgetsCategoryMissing.
  ///
  /// In en, this message translates to:
  /// **'This category no longer exists.'**
  String get budgetsCategoryMissing;

  /// No description provided for @budgetsTransactionsInPeriod.
  ///
  /// In en, this message translates to:
  /// **'Transactions in this period'**
  String get budgetsTransactionsInPeriod;

  /// No description provided for @budgetsNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this period.'**
  String get budgetsNoTransactions;

  /// No description provided for @budgetsSpentNoBudget.
  ///
  /// In en, this message translates to:
  /// **'spent · no budget set'**
  String get budgetsSpentNoBudget;

  /// No description provided for @budgetsBudgetedThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'Budgeted this period'**
  String get budgetsBudgetedThisPeriod;

  /// No description provided for @budgetsCarriedIn.
  ///
  /// In en, this message translates to:
  /// **'Carried in from last period'**
  String get budgetsCarriedIn;

  /// No description provided for @budgetsRollsOverNext.
  ///
  /// In en, this message translates to:
  /// **'Rolls over if the period ended now'**
  String get budgetsRollsOverNext;

  /// No description provided for @budgetsWarningAt.
  ///
  /// In en, this message translates to:
  /// **'Warning at'**
  String get budgetsWarningAt;

  /// No description provided for @budgetsEditAmount.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get budgetsEditAmount;

  /// No description provided for @budgetsSetBudget.
  ///
  /// In en, this message translates to:
  /// **'Set budget'**
  String get budgetsSetBudget;

  /// No description provided for @budgetsRolloverOption.
  ///
  /// In en, this message translates to:
  /// **'Rollover'**
  String get budgetsRolloverOption;

  /// No description provided for @budgetsThresholdOption.
  ///
  /// In en, this message translates to:
  /// **'Warning threshold'**
  String get budgetsThresholdOption;

  /// No description provided for @budgetsDefaultValue.
  ///
  /// In en, this message translates to:
  /// **'Default ({value})'**
  String budgetsDefaultValue(String value);

  /// No description provided for @budgetsHistory.
  ///
  /// In en, this message translates to:
  /// **'Last periods'**
  String get budgetsHistory;

  /// No description provided for @budgetsHistoryRow.
  ///
  /// In en, this message translates to:
  /// **'{period}: {spent} spent, budget {budget}'**
  String budgetsHistoryRow(String period, String spent, String budget);

  /// No description provided for @budgetsHistoryLegend.
  ///
  /// In en, this message translates to:
  /// **'Bars show spending; the tick marks the budget.'**
  String get budgetsHistoryLegend;

  /// No description provided for @budgetsSplitLine.
  ///
  /// In en, this message translates to:
  /// **'split'**
  String get budgetsSplitLine;

  /// No description provided for @budgetsAlertOverTitle.
  ///
  /// In en, this message translates to:
  /// **'{category} is over budget'**
  String budgetsAlertOverTitle(String category);

  /// No description provided for @budgetsAlertOverBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} over budget this period.'**
  String budgetsAlertOverBody(String amount);

  /// No description provided for @budgetsAlertWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'{category} is nearly used up'**
  String budgetsAlertWarningTitle(String category);

  /// No description provided for @budgetsAlertWarningBody.
  ///
  /// In en, this message translates to:
  /// **'{percent}% used, {amount} left.'**
  String budgetsAlertWarningBody(int percent, String amount);

  /// No description provided for @budgetsAlertLowBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Low balance: {account}'**
  String budgetsAlertLowBalanceTitle(String account);

  /// No description provided for @budgetsAlertLowBalanceBody.
  ///
  /// In en, this message translates to:
  /// **'Balance {balance} is below {threshold}.'**
  String budgetsAlertLowBalanceBody(String balance, String threshold);

  /// No description provided for @budgetsPlannedAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} planned'**
  String budgetsPlannedAmount(String amount);

  /// No description provided for @budgetsPlannedOver.
  ///
  /// In en, this message translates to:
  /// **'Planned: {amount} over'**
  String budgetsPlannedOver(String amount);

  /// No description provided for @budgetsAfterPlanned.
  ///
  /// In en, this message translates to:
  /// **'After planned: {amount} left'**
  String budgetsAfterPlanned(String amount);

  /// No description provided for @budgetsAfterPlannedOver.
  ///
  /// In en, this message translates to:
  /// **'After planned: {amount} over'**
  String budgetsAfterPlannedOver(String amount);

  /// No description provided for @budgetsOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get budgetsOutstanding;

  /// No description provided for @budgetsOutstandingHint.
  ///
  /// In en, this message translates to:
  /// **'Not spent yet. Counts once it is booked.'**
  String get budgetsOutstandingHint;

  /// No description provided for @budgetsUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get budgetsUpcoming;

  /// No description provided for @budgetsDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get budgetsDue;

  /// No description provided for @budgetsOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get budgetsOverdue;

  /// No description provided for @budgetsExpectedIncome.
  ///
  /// In en, this message translates to:
  /// **'{amount} expected income, not included until it arrives'**
  String budgetsExpectedIncome(String amount);

  /// No description provided for @budgetsRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get budgetsRepeat;

  /// No description provided for @budgetsRepeatOnce.
  ///
  /// In en, this message translates to:
  /// **'This period only'**
  String get budgetsRepeatOnce;

  /// No description provided for @budgetsRepeatEvery.
  ///
  /// In en, this message translates to:
  /// **'Every period'**
  String get budgetsRepeatEvery;

  /// No description provided for @budgetsRepeatCount.
  ///
  /// In en, this message translates to:
  /// **'For a number of periods'**
  String get budgetsRepeatCount;

  /// No description provided for @budgetsRepeatUntil.
  ///
  /// In en, this message translates to:
  /// **'Until a date'**
  String get budgetsRepeatUntil;

  /// No description provided for @budgetsRepeatPeriods.
  ///
  /// In en, this message translates to:
  /// **'How many times'**
  String get budgetsRepeatPeriods;

  /// No description provided for @budgetsRepeatInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval'**
  String get budgetsRepeatInterval;

  /// No description provided for @budgetsRepeatNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter 1 or more'**
  String get budgetsRepeatNumberInvalid;

  /// No description provided for @budgetsRepeatUntilDate.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String budgetsRepeatUntilDate(String date);

  /// No description provided for @budgetsEveryN.
  ///
  /// In en, this message translates to:
  /// **'{every, plural, =1{every period} other{every {every} periods}}'**
  String budgetsEveryN(int every);

  /// No description provided for @budgetsRepeatsEvery.
  ///
  /// In en, this message translates to:
  /// **'Repeats {every} from {period}'**
  String budgetsRepeatsEvery(String every, String period);

  /// No description provided for @budgetsRepeatsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Only in {period}} other{Repeats {every} from {period}, {count} times}}'**
  String budgetsRepeatsCount(int count, String every, String period);

  /// No description provided for @budgetsRepeatsUntil.
  ///
  /// In en, this message translates to:
  /// **'Repeats {every} from {period} until {date}'**
  String budgetsRepeatsUntil(String every, String period, String date);

  /// No description provided for @budgetsScopeChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change a repeating budget'**
  String get budgetsScopeChangeTitle;

  /// No description provided for @budgetsScopeRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove a repeating budget'**
  String get budgetsScopeRemoveTitle;

  /// No description provided for @budgetsScopeThis.
  ///
  /// In en, this message translates to:
  /// **'Only this period'**
  String get budgetsScopeThis;

  /// No description provided for @budgetsScopeFollowing.
  ///
  /// In en, this message translates to:
  /// **'This and following periods'**
  String get budgetsScopeFollowing;

  /// No description provided for @budgetsScopeHint.
  ///
  /// In en, this message translates to:
  /// **'Budgets you set by hand in later periods stay as they are.'**
  String get budgetsScopeHint;

  /// No description provided for @budgetsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Budget for {category} removed'**
  String budgetsRemoved(String category);

  /// No description provided for @budgetsRepeatOption.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get budgetsRepeatOption;

  /// No description provided for @budgetsStopRepeating.
  ///
  /// In en, this message translates to:
  /// **'Stop repeating'**
  String get budgetsStopRepeating;

  /// No description provided for @budgetsStopRepeatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop repeating {category}?'**
  String budgetsStopRepeatingTitle(String category);

  /// No description provided for @budgetsStopRepeatingMessage.
  ///
  /// In en, this message translates to:
  /// **'The budget of this period stays. Later periods get no budget for {category}, except budgets you set by hand.'**
  String budgetsStopRepeatingMessage(String category);

  /// No description provided for @budgetsStoppedRepeating.
  ///
  /// In en, this message translates to:
  /// **'{category} no longer repeats'**
  String budgetsStoppedRepeating(String category);

  /// No description provided for @budgetsRepeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat these budgets every period'**
  String get budgetsRepeatAll;

  /// No description provided for @budgetsRepeatAllDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 budget now repeats every period} other{{count} budgets now repeat every period}}'**
  String budgetsRepeatAllDone(int count);

  /// No description provided for @budgetsLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get budgetsLength;

  /// No description provided for @budgetsLengthPeriod.
  ///
  /// In en, this message translates to:
  /// **'Budget period ({type})'**
  String budgetsLengthPeriod(String type);

  /// No description provided for @budgetsLengthWeek.
  ///
  /// In en, this message translates to:
  /// **'One week'**
  String get budgetsLengthWeek;

  /// No description provided for @budgetsLengthMonth.
  ///
  /// In en, this message translates to:
  /// **'One month'**
  String get budgetsLengthMonth;

  /// No description provided for @budgetsLengthQuarter.
  ///
  /// In en, this message translates to:
  /// **'One quarter'**
  String get budgetsLengthQuarter;

  /// No description provided for @budgetsLengthYear.
  ///
  /// In en, this message translates to:
  /// **'One year'**
  String get budgetsLengthYear;

  /// No description provided for @budgetsEveryWeek.
  ///
  /// In en, this message translates to:
  /// **'{every, plural, =1{every week} other{every {every} weeks}}'**
  String budgetsEveryWeek(int every);

  /// No description provided for @budgetsEveryMonth.
  ///
  /// In en, this message translates to:
  /// **'{every, plural, =1{every month} other{every {every} months}}'**
  String budgetsEveryMonth(int every);

  /// No description provided for @budgetsEveryQuarter.
  ///
  /// In en, this message translates to:
  /// **'{every, plural, =1{every quarter} other{every {every} quarters}}'**
  String budgetsEveryQuarter(int every);

  /// No description provided for @budgetsEveryYear.
  ///
  /// In en, this message translates to:
  /// **'{every, plural, =1{every year} other{every {every} years}}'**
  String budgetsEveryYear(int every);

  /// No description provided for @budgetsOnlyIn.
  ///
  /// In en, this message translates to:
  /// **'Only {period}'**
  String budgetsOnlyIn(String period);

  /// No description provided for @budgetsWindowLabel.
  ///
  /// In en, this message translates to:
  /// **'{length} · {period}'**
  String budgetsWindowLabel(String length, String period);

  /// No description provided for @budgetsWindowsNote.
  ///
  /// In en, this message translates to:
  /// **'Totals don\'t include budgets with their own length.'**
  String get budgetsWindowsNote;

  /// No description provided for @budgetsWindowsInPeriod.
  ///
  /// In en, this message translates to:
  /// **'Within this period'**
  String get budgetsWindowsInPeriod;

  /// No description provided for @budgetsRemovedFollowing.
  ///
  /// In en, this message translates to:
  /// **'{category} removed from this period on'**
  String budgetsRemovedFollowing(String category);

  /// No description provided for @budgetsBudgetedFor.
  ///
  /// In en, this message translates to:
  /// **'Budgeted for {period}'**
  String budgetsBudgetedFor(String period);

  /// No description provided for @budgetsTransactionsIn.
  ///
  /// In en, this message translates to:
  /// **'Transactions in {period}'**
  String budgetsTransactionsIn(String period);

  /// No description provided for @budgetsRepeatsShort.
  ///
  /// In en, this message translates to:
  /// **'repeats'**
  String get budgetsRepeatsShort;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @categoriesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get categoriesAdd;

  /// No description provided for @categoriesAddSub.
  ///
  /// In en, this message translates to:
  /// **'Add subcategory'**
  String get categoriesAddSub;

  /// No description provided for @categoriesNew.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get categoriesNew;

  /// No description provided for @categoriesNewSub.
  ///
  /// In en, this message translates to:
  /// **'New subcategory'**
  String get categoriesNewSub;

  /// No description provided for @categoriesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get categoriesEdit;

  /// No description provided for @categoriesName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get categoriesName;

  /// No description provided for @categoriesNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get categoriesNameRequired;

  /// No description provided for @categoriesParent.
  ///
  /// In en, this message translates to:
  /// **'Parent category'**
  String get categoriesParent;

  /// No description provided for @categoriesTopLevel.
  ///
  /// In en, this message translates to:
  /// **'None (top level)'**
  String get categoriesTopLevel;

  /// No description provided for @categoriesParentLocked.
  ///
  /// In en, this message translates to:
  /// **'Has subcategories, so it stays top level'**
  String get categoriesParentLocked;

  /// No description provided for @categoriesIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get categoriesIcon;

  /// No description provided for @categoriesPickIcon.
  ///
  /// In en, this message translates to:
  /// **'Choose an icon'**
  String get categoriesPickIcon;

  /// No description provided for @categoriesIconLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon {name}'**
  String categoriesIconLabel(String name);

  /// No description provided for @categoriesColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get categoriesColor;

  /// No description provided for @categoriesColorNone.
  ///
  /// In en, this message translates to:
  /// **'Default colour'**
  String get categoriesColorNone;

  /// No description provided for @categoriesColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Colour {n}'**
  String categoriesColorLabel(int n);

  /// No description provided for @categoriesFavourite.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get categoriesFavourite;

  /// No description provided for @categoriesUnfavourite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get categoriesUnfavourite;

  /// No description provided for @categoriesFavouriteDesc.
  ///
  /// In en, this message translates to:
  /// **'Shown first when picking a category'**
  String get categoriesFavouriteDesc;

  /// No description provided for @categoriesBudgetSection.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get categoriesBudgetSection;

  /// No description provided for @categoriesRollover.
  ///
  /// In en, this message translates to:
  /// **'Rollover'**
  String get categoriesRollover;

  /// No description provided for @categoriesUseDefault.
  ///
  /// In en, this message translates to:
  /// **'Budget setting ({value})'**
  String categoriesUseDefault(String value);

  /// No description provided for @categoriesWarnThreshold.
  ///
  /// In en, this message translates to:
  /// **'Warning threshold'**
  String get categoriesWarnThreshold;

  /// No description provided for @categoriesWarnThresholdHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the budget setting'**
  String get categoriesWarnThresholdHint;

  /// No description provided for @categoriesThresholdInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a value from 1 to 100'**
  String get categoriesThresholdInvalid;

  /// No description provided for @categoriesArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get categoriesArchived;

  /// No description provided for @categoriesArchivedDesc.
  ///
  /// In en, this message translates to:
  /// **'Hidden from pickers; existing transactions keep it'**
  String get categoriesArchivedDesc;

  /// No description provided for @categoriesArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get categoriesArchive;

  /// No description provided for @categoriesUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get categoriesUnarchive;

  /// No description provided for @categoriesShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get categoriesShowArchived;

  /// No description provided for @categoriesHideArchived.
  ///
  /// In en, this message translates to:
  /// **'Hide archived'**
  String get categoriesHideArchived;

  /// No description provided for @categoriesMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get categoriesMoreActions;

  /// No description provided for @categoriesReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get categoriesReorder;

  /// No description provided for @categoriesReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder. Subcategories are sorted from their parent.'**
  String get categoriesReorderHint;

  /// No description provided for @categoriesReorderChildren.
  ///
  /// In en, this message translates to:
  /// **'Reorder subcategories'**
  String get categoriesReorderChildren;

  /// No description provided for @categoriesSubCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subcategory} other{{count} subcategories}}'**
  String categoriesSubCount(int count);

  /// No description provided for @categoriesUsage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Not used yet} =1{1 transaction} other{{count} transactions}}'**
  String categoriesUsage(int count);

  /// No description provided for @categoriesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No categories yet. Start with the default set or create your own.'**
  String get categoriesEmpty;

  /// No description provided for @categoriesEmptyExpense.
  ///
  /// In en, this message translates to:
  /// **'No expense categories yet.'**
  String get categoriesEmptyExpense;

  /// No description provided for @categoriesEmptyIncome.
  ///
  /// In en, this message translates to:
  /// **'No income categories yet.'**
  String get categoriesEmptyIncome;

  /// No description provided for @categoriesAddDefaults.
  ///
  /// In en, this message translates to:
  /// **'Add default categories'**
  String get categoriesAddDefaults;

  /// No description provided for @categoriesMergeAction.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get categoriesMergeAction;

  /// No description provided for @categoriesMergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge?'**
  String get categoriesMergeTitle;

  /// No description provided for @categoriesMergeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Move everything from \"{source}\" into \"{target}\"? Transactions, splits, budgets and subcategories move over and \"{source}\" is deleted. Budgets of the same period are added up. Repeating budgets of \"{target}\" stay; those of \"{source}\" take over when they end.'**
  String categoriesMergeConfirm(String source, String target);

  /// No description provided for @categoriesMerged.
  ///
  /// In en, this message translates to:
  /// **'\"{source}\" merged into \"{target}\"'**
  String categoriesMerged(String source, String target);

  /// No description provided for @categoriesMergeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Choose a different category of the same type.'**
  String get categoriesMergeInvalid;

  /// No description provided for @categoriesMergeNest.
  ///
  /// In en, this message translates to:
  /// **'A category with subcategories can only be merged into a top-level category.'**
  String get categoriesMergeNest;

  /// No description provided for @categoriesInvalidParent.
  ///
  /// In en, this message translates to:
  /// **'Choose a top-level category of the same type as parent.'**
  String get categoriesInvalidParent;

  /// No description provided for @categoriesHasChildrenError.
  ///
  /// In en, this message translates to:
  /// **'A category with subcategories can\'t become a subcategory.'**
  String get categoriesHasChildrenError;

  /// No description provided for @categoriesInUseError.
  ///
  /// In en, this message translates to:
  /// **'This category is in use.'**
  String get categoriesInUseError;

  /// No description provided for @categoriesNotFound.
  ///
  /// In en, this message translates to:
  /// **'This category no longer exists.'**
  String get categoriesNotFound;

  /// No description provided for @categoriesInUseTitle.
  ///
  /// In en, this message translates to:
  /// **'Category in use'**
  String get categoriesInUseTitle;

  /// No description provided for @categoriesDeleteInUse.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is used by {count} transactions and {budgets} budgets. Merge it into another category to keep the history together, or archive it.'**
  String categoriesDeleteInUse(String name, int count, int budgets);

  /// No description provided for @categoriesDeleteHasChildren.
  ///
  /// In en, this message translates to:
  /// **'Delete or move the subcategories of \"{name}\" first.'**
  String categoriesDeleteHasChildren(String name);

  /// No description provided for @categoriesDeleted.
  ///
  /// In en, this message translates to:
  /// **'Category deleted'**
  String get categoriesDeleted;

  /// No description provided for @categoriesModuleOff.
  ///
  /// In en, this message translates to:
  /// **'{module} is switched off. Turn it on in Settings › Navigation & modules.'**
  String categoriesModuleOff(String module);

  /// No description provided for @categoriesOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get categoriesOpenSettings;

  /// No description provided for @categoriesTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get categoriesTagsTitle;

  /// No description provided for @categoriesTagAdd.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get categoriesTagAdd;

  /// No description provided for @categoriesTagNew.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get categoriesTagNew;

  /// No description provided for @categoriesTagEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit tag'**
  String get categoriesTagEdit;

  /// No description provided for @categoriesTagName.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get categoriesTagName;

  /// No description provided for @categoriesTagTaken.
  ///
  /// In en, this message translates to:
  /// **'A tag with this name already exists'**
  String get categoriesTagTaken;

  /// No description provided for @categoriesTagsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tags yet. Tags cut across categories, e.g. #vacation-2026 or #reimbursable.'**
  String get categoriesTagsEmpty;

  /// No description provided for @categoriesTagMergeInto.
  ///
  /// In en, this message translates to:
  /// **'Merge #{name} into…'**
  String categoriesTagMergeInto(String name);

  /// No description provided for @categoriesTagMergeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Move all transactions tagged #{source} to #{target}? #{source} is deleted; transactions with both keep one tag.'**
  String categoriesTagMergeConfirm(String source, String target);

  /// No description provided for @categoriesTagNoMergeTarget.
  ///
  /// In en, this message translates to:
  /// **'There is no other tag to merge into.'**
  String get categoriesTagNoMergeTarget;

  /// No description provided for @categoriesTagDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{It is removed from 1 transaction.} other{It is removed from {count} transactions.}}'**
  String categoriesTagDeleteMessage(int count);

  /// No description provided for @categoriesTagDeleted.
  ///
  /// In en, this message translates to:
  /// **'Tag deleted'**
  String get categoriesTagDeleted;

  /// No description provided for @categoriesFieldsTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom fields'**
  String get categoriesFieldsTitle;

  /// No description provided for @categoriesFieldAdd.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get categoriesFieldAdd;

  /// No description provided for @categoriesFieldNew.
  ///
  /// In en, this message translates to:
  /// **'New custom field'**
  String get categoriesFieldNew;

  /// No description provided for @categoriesFieldEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit custom field'**
  String get categoriesFieldEdit;

  /// No description provided for @categoriesFieldName.
  ///
  /// In en, this message translates to:
  /// **'Field name'**
  String get categoriesFieldName;

  /// No description provided for @categoriesFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get categoriesFieldType;

  /// No description provided for @categoriesFieldTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get categoriesFieldTypeText;

  /// No description provided for @categoriesFieldTypeNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get categoriesFieldTypeNumber;

  /// No description provided for @categoriesFieldTypeDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get categoriesFieldTypeDate;

  /// No description provided for @categoriesFieldTypeSelect.
  ///
  /// In en, this message translates to:
  /// **'Single choice'**
  String get categoriesFieldTypeSelect;

  /// No description provided for @categoriesFieldTypeMultiselect.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get categoriesFieldTypeMultiselect;

  /// No description provided for @categoriesFieldTypeBoolean.
  ///
  /// In en, this message translates to:
  /// **'Checkbox'**
  String get categoriesFieldTypeBoolean;

  /// No description provided for @categoriesFieldTypeLocked.
  ///
  /// In en, this message translates to:
  /// **'The type can\'t change because values exist.'**
  String get categoriesFieldTypeLocked;

  /// No description provided for @categoriesFieldAppliesTo.
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get categoriesFieldAppliesTo;

  /// No description provided for @categoriesFieldTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get categoriesFieldTransactions;

  /// No description provided for @categoriesFieldAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get categoriesFieldAccounts;

  /// No description provided for @categoriesFieldOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get categoriesFieldOptions;

  /// No description provided for @categoriesFieldOptionHint.
  ///
  /// In en, this message translates to:
  /// **'New option'**
  String get categoriesFieldOptionHint;

  /// No description provided for @categoriesFieldAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get categoriesFieldAddOption;

  /// No description provided for @categoriesFieldOptionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one option'**
  String get categoriesFieldOptionsRequired;

  /// No description provided for @categoriesFieldOptionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 option} other{{count} options}}'**
  String categoriesFieldOptionCount(int count);

  /// No description provided for @categoriesFieldValues.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No values} =1{1 value} other{{count} values}}'**
  String categoriesFieldValues(int count);

  /// No description provided for @categoriesFieldArchivedDesc.
  ///
  /// In en, this message translates to:
  /// **'Hidden when entering data; existing values stay'**
  String get categoriesFieldArchivedDesc;

  /// No description provided for @categoriesFieldDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Its 1 stored value is deleted too.} other{Its {count} stored values are deleted too.}}'**
  String categoriesFieldDeleteMessage(int count);

  /// No description provided for @categoriesFieldDeleted.
  ///
  /// In en, this message translates to:
  /// **'Custom field deleted'**
  String get categoriesFieldDeleted;

  /// No description provided for @categoriesFieldsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No custom fields yet. Add fields such as \"Receipt no.\" or \"Project\" to transactions or accounts.'**
  String get categoriesFieldsEmpty;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiet Ledger'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get navTransactions;

  /// No description provided for @navPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get navPlan;

  /// No description provided for @navForecast.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get navForecast;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @navAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get navAccounts;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get navImport;

  /// No description provided for @navExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get navExport;

  /// No description provided for @navRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get navRules;

  /// No description provided for @navGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get navGoals;

  /// No description provided for @navScenarios.
  ///
  /// In en, this message translates to:
  /// **'Scenarios'**
  String get navScenarios;

  /// No description provided for @navCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get navCategories;

  /// No description provided for @navTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get navTags;

  /// No description provided for @navCollapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get navCollapseSidebar;

  /// No description provided for @navExpandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get navExpandSidebar;

  /// No description provided for @addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get addTransaction;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get commonEmpty;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {message}'**
  String commonError(String message);

  /// No description provided for @commonDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String commonDeleteConfirm(String name);

  /// No description provided for @commonComingSoon.
  ///
  /// In en, this message translates to:
  /// **'This screen is not available yet.'**
  String get commonComingSoon;

  /// No description provided for @typeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get typeExpense;

  /// No description provided for @typeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get typeIncome;

  /// No description provided for @typeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get typeTransfer;

  /// No description provided for @statusCleared.
  ///
  /// In en, this message translates to:
  /// **'Cleared'**
  String get statusCleared;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get statusPlanned;

  /// No description provided for @privacyHiddenAmount.
  ///
  /// In en, this message translates to:
  /// **'Hidden amount, tap to reveal'**
  String get privacyHiddenAmount;

  /// No description provided for @privacyToggle.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts'**
  String get privacyToggle;

  /// No description provided for @moreTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get moreTemplates;

  /// No description provided for @bootErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'The database could not be opened'**
  String get bootErrorTitle;

  /// No description provided for @dashWidgetOptions.
  ///
  /// In en, this message translates to:
  /// **'Widget options'**
  String get dashWidgetOptions;

  /// No description provided for @dashNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get dashNetWorth;

  /// No description provided for @dashThisMonth.
  ///
  /// In en, this message translates to:
  /// **'this month'**
  String get dashThisMonth;

  /// No description provided for @dashAcrossAccounts.
  ///
  /// In en, this message translates to:
  /// **'across {count, plural, =1{1 account} other{{count} accounts}}'**
  String dashAcrossAccounts(int count);

  /// No description provided for @dashIn12Months.
  ///
  /// In en, this message translates to:
  /// **'{amount} in 12 months'**
  String dashIn12Months(String amount);

  /// No description provided for @dashNetWorthChart.
  ///
  /// In en, this message translates to:
  /// **'Net worth over the last 12 months'**
  String get dashNetWorthChart;

  /// No description provided for @dashLast12Months.
  ///
  /// In en, this message translates to:
  /// **'Last 12 months'**
  String get dashLast12Months;

  /// No description provided for @dashSoFar.
  ///
  /// In en, this message translates to:
  /// **'{month} so far'**
  String dashSoFar(String month);

  /// No description provided for @dashExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get dashExpenses;

  /// No description provided for @dashSavingsRate.
  ///
  /// In en, this message translates to:
  /// **'Savings rate'**
  String get dashSavingsRate;

  /// No description provided for @dashTopCategories.
  ///
  /// In en, this message translates to:
  /// **'Top categories'**
  String get dashTopCategories;

  /// No description provided for @dashNoSpending.
  ///
  /// In en, this message translates to:
  /// **'No spending in this period'**
  String get dashNoSpending;

  /// No description provided for @dashUncategorised.
  ///
  /// In en, this message translates to:
  /// **'Uncategorised'**
  String get dashUncategorised;

  /// No description provided for @dashAllAccounts.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get dashAllAccounts;

  /// No description provided for @dashViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get dashViewAll;

  /// No description provided for @dashBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get dashBudgets;

  /// No description provided for @dashAllBudgets.
  ///
  /// In en, this message translates to:
  /// **'All budgets'**
  String get dashAllBudgets;

  /// No description provided for @dashUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get dashUpcoming;

  /// No description provided for @dashNextDays.
  ///
  /// In en, this message translates to:
  /// **'next {days} days'**
  String dashNextDays(int days);

  /// No description provided for @dashCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get dashCalendar;

  /// No description provided for @dashNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Nothing due in the next {days} days'**
  String dashNoUpcoming(int days);

  /// No description provided for @dashGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get dashGoals;

  /// No description provided for @dashNoGoals.
  ///
  /// In en, this message translates to:
  /// **'No savings goals yet'**
  String get dashNoGoals;

  /// No description provided for @dashRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get dashRecent;

  /// No description provided for @dashNoBudgets.
  ///
  /// In en, this message translates to:
  /// **'No budgets for this period'**
  String get dashNoBudgets;

  /// No description provided for @dashSetUpBudgets.
  ///
  /// In en, this message translates to:
  /// **'Set up budgets'**
  String get dashSetUpBudgets;

  /// No description provided for @dashOver.
  ///
  /// In en, this message translates to:
  /// **'{amount} over'**
  String dashOver(String amount);

  /// No description provided for @dashOf.
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String dashOf(String amount);

  /// No description provided for @dashEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit dashboard'**
  String get dashEdit;

  /// No description provided for @dashEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit dashboard'**
  String get dashEditTitle;

  /// No description provided for @dashAddWidget.
  ///
  /// In en, this message translates to:
  /// **'Add widget'**
  String get dashAddWidget;

  /// No description provided for @dashRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get dashRemove;

  /// No description provided for @dashMakeWide.
  ///
  /// In en, this message translates to:
  /// **'Make wide'**
  String get dashMakeWide;

  /// No description provided for @dashMakeNormal.
  ///
  /// In en, this message translates to:
  /// **'Make normal width'**
  String get dashMakeNormal;

  /// No description provided for @dashChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose account'**
  String get dashChooseAccount;

  /// No description provided for @dashResetLayout.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get dashResetLayout;

  /// No description provided for @dashLayoutPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get dashLayoutPhone;

  /// No description provided for @dashLayoutWide.
  ///
  /// In en, this message translates to:
  /// **'Tablet & desktop'**
  String get dashLayoutWide;

  /// No description provided for @dashPrevPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get dashPrevPeriod;

  /// No description provided for @dashNextPeriod.
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get dashNextPeriod;

  /// No description provided for @dashToday.
  ///
  /// In en, this message translates to:
  /// **'Back to today'**
  String get dashToday;

  /// No description provided for @dashSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get dashSearchHint;

  /// No description provided for @dashNewTransaction.
  ///
  /// In en, this message translates to:
  /// **'New transaction'**
  String get dashNewTransaction;

  /// No description provided for @dashAutoPost.
  ///
  /// In en, this message translates to:
  /// **'auto-post'**
  String get dashAutoPost;

  /// No description provided for @dashConfirm.
  ///
  /// In en, this message translates to:
  /// **'confirm'**
  String get dashConfirm;

  /// No description provided for @dashConfirmDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'confirm {days} days before'**
  String dashConfirmDaysBefore(int days);

  /// No description provided for @dashWelcomeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add your first transaction to see your dashboard come alive.'**
  String get dashWelcomeEmpty;

  /// No description provided for @dashWTypenetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get dashWTypenetWorth;

  /// No description provided for @dashWTypemonthSummary.
  ///
  /// In en, this message translates to:
  /// **'Month summary'**
  String get dashWTypemonthSummary;

  /// No description provided for @dashWTypebudgets.
  ///
  /// In en, this message translates to:
  /// **'Budget progress'**
  String get dashWTypebudgets;

  /// No description provided for @dashWTypeupcomingBills.
  ///
  /// In en, this message translates to:
  /// **'Upcoming bills'**
  String get dashWTypeupcomingBills;

  /// No description provided for @dashWTypeforecast.
  ///
  /// In en, this message translates to:
  /// **'Mini forecast'**
  String get dashWTypeforecast;

  /// No description provided for @dashWTypeaccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get dashWTypeaccounts;

  /// No description provided for @dashWTypegoals.
  ///
  /// In en, this message translates to:
  /// **'Goal progress'**
  String get dashWTypegoals;

  /// No description provided for @dashWTypetopCategories.
  ///
  /// In en, this message translates to:
  /// **'Top categories'**
  String get dashWTypetopCategories;

  /// No description provided for @dashWTyperecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get dashWTyperecentTransactions;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export & backup'**
  String get exportTitle;

  /// No description provided for @exportTxnTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions as CSV'**
  String get exportTxnTitle;

  /// No description provided for @exportTxnDesc.
  ///
  /// In en, this message translates to:
  /// **'Export transactions of a period and selected accounts, e.g. for Excel.'**
  String get exportTxnDesc;

  /// No description provided for @exportPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get exportPeriod;

  /// No description provided for @exportPeriodThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get exportPeriodThisMonth;

  /// No description provided for @exportPeriodLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get exportPeriodLastMonth;

  /// No description provided for @exportPeriodThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get exportPeriodThisYear;

  /// No description provided for @exportPeriodLastYear.
  ///
  /// In en, this message translates to:
  /// **'Last year'**
  String get exportPeriodLastYear;

  /// No description provided for @exportPeriodLast12Months.
  ///
  /// In en, this message translates to:
  /// **'Last 12 months'**
  String get exportPeriodLast12Months;

  /// No description provided for @exportPeriodAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get exportPeriodAll;

  /// No description provided for @exportPeriodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get exportPeriodCustom;

  /// No description provided for @exportPeriodRange.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String exportPeriodRange(String start, String end);

  /// No description provided for @exportAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get exportAccounts;

  /// No description provided for @exportAccountsAll.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get exportAccountsAll;

  /// No description provided for @exportAccountsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 account} other{{count} accounts}}'**
  String exportAccountsSelected(int count);

  /// No description provided for @exportFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get exportFiles;

  /// No description provided for @exportLayoutFlat.
  ///
  /// In en, this message translates to:
  /// **'One file'**
  String get exportLayoutFlat;

  /// No description provided for @exportLayoutPerAccount.
  ///
  /// In en, this message translates to:
  /// **'One per account'**
  String get exportLayoutPerAccount;

  /// No description provided for @exportLayoutPerAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Saved together as a zip archive.'**
  String get exportLayoutPerAccountHint;

  /// No description provided for @exportOptions.
  ///
  /// In en, this message translates to:
  /// **'CSV options'**
  String get exportOptions;

  /// No description provided for @exportOptionsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit options'**
  String get exportOptionsEdit;

  /// No description provided for @exportHeaderRow.
  ///
  /// In en, this message translates to:
  /// **'Header row'**
  String get exportHeaderRow;

  /// No description provided for @exportColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get exportColumns;

  /// No description provided for @exportColumnsSummary.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} columns'**
  String exportColumnsSummary(int selected, int total);

  /// No description provided for @exportColumnsHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to change the order.'**
  String get exportColumnsHint;

  /// No description provided for @exportColumnsMin.
  ///
  /// In en, this message translates to:
  /// **'Select at least one column.'**
  String get exportColumnsMin;

  /// No description provided for @exportApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get exportApply;

  /// No description provided for @exportUseDefaults.
  ///
  /// In en, this message translates to:
  /// **'Defaults from settings'**
  String get exportUseDefaults;

  /// No description provided for @exportPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get exportPresets;

  /// No description provided for @exportPresetsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved presets yet.'**
  String get exportPresetsEmpty;

  /// No description provided for @exportPresetSave.
  ///
  /// In en, this message translates to:
  /// **'Save as preset'**
  String get exportPresetSave;

  /// No description provided for @exportPresetName.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get exportPresetName;

  /// No description provided for @exportPresetSaved.
  ///
  /// In en, this message translates to:
  /// **'Preset “{name}” saved'**
  String exportPresetSaved(String name);

  /// No description provided for @exportPresetDeleted.
  ///
  /// In en, this message translates to:
  /// **'Preset “{name}” deleted'**
  String exportPresetDeleted(String name);

  /// No description provided for @exportPresetApplied.
  ///
  /// In en, this message translates to:
  /// **'Preset “{name}” applied'**
  String exportPresetApplied(String name);

  /// No description provided for @exportPresetDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete preset “{name}”'**
  String exportPresetDelete(String name);

  /// No description provided for @exportPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get exportPreview;

  /// No description provided for @exportPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'first {count} rows'**
  String exportPreviewHint(int count);

  /// No description provided for @exportPreviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions match the period and accounts.'**
  String get exportPreviewEmpty;

  /// No description provided for @exportRun.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportRun;

  /// No description provided for @exportRunZip.
  ///
  /// In en, this message translates to:
  /// **'Export zip'**
  String get exportRunZip;

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {location}'**
  String exportSaved(String location);

  /// No description provided for @exportSavedShort.
  ///
  /// In en, this message translates to:
  /// **'Export saved'**
  String get exportSavedShort;

  /// No description provided for @exportShared.
  ///
  /// In en, this message translates to:
  /// **'Export shared'**
  String get exportShared;

  /// No description provided for @exportDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Download started'**
  String get exportDownloaded;

  /// No description provided for @exportRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No rows} =1{1 row} other{{count} rows}}'**
  String exportRows(int count);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {message}'**
  String exportFailed(String message);

  /// No description provided for @exportWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get exportWorking;

  /// No description provided for @exportBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Full backup'**
  String get exportBackupTitle;

  /// No description provided for @exportBackupDesc.
  ///
  /// In en, this message translates to:
  /// **'All data and settings as a zip of CSV files with a checksum manifest. Use it as a backup or to move to another device.'**
  String get exportBackupDesc;

  /// No description provided for @exportBackupRun.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get exportBackupRun;

  /// No description provided for @exportBackupDone.
  ///
  /// In en, this message translates to:
  /// **'Backup created and verified ({count} rows)'**
  String exportBackupDone(int count);

  /// No description provided for @exportRestoreRun.
  ///
  /// In en, this message translates to:
  /// **'Restore backup…'**
  String get exportRestoreRun;

  /// No description provided for @exportRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get exportRestoreTitle;

  /// No description provided for @exportRestoreCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get exportRestoreCreated;

  /// No description provided for @exportRestoreAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get exportRestoreAppVersion;

  /// No description provided for @exportRestoreDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get exportRestoreDevice;

  /// No description provided for @exportRestoreThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get exportRestoreThisDevice;

  /// No description provided for @exportRestoreOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'Another device'**
  String get exportRestoreOtherDevice;

  /// No description provided for @exportRestoreTotalRows.
  ///
  /// In en, this message translates to:
  /// **'Rows in total'**
  String get exportRestoreTotalRows;

  /// No description provided for @exportRestoreWarning.
  ///
  /// In en, this message translates to:
  /// **'This replaces all data and settings on this device with the backup. A safety copy of the current data is kept on this device first (Export & backup › Safety copies).'**
  String get exportRestoreWarning;

  /// No description provided for @exportRestoreBackupFirst.
  ///
  /// In en, this message translates to:
  /// **'Also save a backup of the current data elsewhere'**
  String get exportRestoreBackupFirst;

  /// No description provided for @exportRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'Replace all data'**
  String get exportRestoreConfirm;

  /// No description provided for @exportRestoreAborted.
  ///
  /// In en, this message translates to:
  /// **'Restore cancelled. Nothing was changed.'**
  String get exportRestoreAborted;

  /// No description provided for @exportRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Backup restored ({count} rows)'**
  String exportRestoreDone(int count);

  /// No description provided for @exportRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed, nothing was changed: {message}'**
  String exportRestoreFailed(String message);

  /// No description provided for @exportErrTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot restore'**
  String get exportErrTitle;

  /// No description provided for @exportErrNotBundle.
  ///
  /// In en, this message translates to:
  /// **'This file is not a backup created by this app.'**
  String get exportErrNotBundle;

  /// No description provided for @exportErrNewerFormat.
  ///
  /// In en, this message translates to:
  /// **'This backup was created by a newer version of the app. Update the app to restore it.'**
  String get exportErrNewerFormat;

  /// No description provided for @exportErrChecksum.
  ///
  /// In en, this message translates to:
  /// **'The backup is damaged: {file} does not match its checksum.'**
  String exportErrChecksum(String file);

  /// No description provided for @exportErrInvalid.
  ///
  /// In en, this message translates to:
  /// **'The backup is damaged: {detail}'**
  String exportErrInvalid(String detail);

  /// No description provided for @exportAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get exportAutoTitle;

  /// No description provided for @exportAutoDesc.
  ///
  /// In en, this message translates to:
  /// **'Regularly writes a full backup to a folder, for example one that a cloud client syncs.'**
  String get exportAutoDesc;

  /// No description provided for @exportAutoSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get exportAutoSchedule;

  /// No description provided for @exportAutoNoFolder.
  ///
  /// In en, this message translates to:
  /// **'No folder chosen'**
  String get exportAutoNoFolder;

  /// No description provided for @exportAutoChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder…'**
  String get exportAutoChooseFolder;

  /// No description provided for @exportAutoLast.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {date}'**
  String exportAutoLast(String date);

  /// No description provided for @exportAutoNever.
  ///
  /// In en, this message translates to:
  /// **'No automatic backup yet'**
  String get exportAutoNever;

  /// No description provided for @exportAutoRunNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get exportAutoRunNow;

  /// No description provided for @exportAutoRunDone.
  ///
  /// In en, this message translates to:
  /// **'Backup written: {file}'**
  String exportAutoRunDone(String file);

  /// No description provided for @exportAutoRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {message}'**
  String exportAutoRunFailed(String message);

  /// No description provided for @exportAutoKeepValue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Keep the newest backup} other{Keep the newest {count} backups}}'**
  String exportAutoKeepValue(int count);

  /// No description provided for @exportAutoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Automatic backups to a folder are not available in the browser. Use “Create backup” instead.'**
  String get exportAutoUnavailable;

  /// No description provided for @exportAutoNeedsFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder to start automatic backups.'**
  String get exportAutoNeedsFolder;

  /// No description provided for @exportAutoSettings.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup settings'**
  String get exportAutoSettings;

  /// No description provided for @exportDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get exportDecrease;

  /// No description provided for @exportIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get exportIncrease;

  /// No description provided for @exportPurgeLast.
  ///
  /// In en, this message translates to:
  /// **'Last clean-up of deleted entries'**
  String get exportPurgeLast;

  /// No description provided for @exportColDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get exportColDate;

  /// No description provided for @exportColValueDate.
  ///
  /// In en, this message translates to:
  /// **'Value date'**
  String get exportColValueDate;

  /// No description provided for @exportColAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get exportColAccount;

  /// No description provided for @exportColType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get exportColType;

  /// No description provided for @exportColAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get exportColAmount;

  /// No description provided for @exportColCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get exportColCurrency;

  /// No description provided for @exportColPayee.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get exportColPayee;

  /// No description provided for @exportColNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get exportColNote;

  /// No description provided for @exportColCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get exportColCategory;

  /// No description provided for @exportColSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get exportColSplit;

  /// No description provided for @exportColTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get exportColTags;

  /// No description provided for @exportColStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get exportColStatus;

  /// No description provided for @exportColTransferAccount.
  ///
  /// In en, this message translates to:
  /// **'Transfer account'**
  String get exportColTransferAccount;

  /// No description provided for @exportColId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get exportColId;

  /// No description provided for @forecastTitle.
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get forecastTitle;

  /// No description provided for @forecastTotal.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get forecastTotal;

  /// No description provided for @forecastChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose account'**
  String get forecastChooseAccount;

  /// No description provided for @forecastHorizon.
  ///
  /// In en, this message translates to:
  /// **'Horizon'**
  String get forecastHorizon;

  /// No description provided for @forecastHorizonShort.
  ///
  /// In en, this message translates to:
  /// **'{months} mo'**
  String forecastHorizonShort(int months);

  /// No description provided for @forecastHorizonLong.
  ///
  /// In en, this message translates to:
  /// **'{months, plural, =1{1 month} other{{months} months}}'**
  String forecastHorizonLong(int months);

  /// No description provided for @forecastHorizonCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get forecastHorizonCustom;

  /// No description provided for @forecastHorizonCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom horizon'**
  String get forecastHorizonCustomTitle;

  /// No description provided for @forecastHorizonMonthsLabel.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get forecastHorizonMonthsLabel;

  /// No description provided for @forecastHorizonRangeError.
  ///
  /// In en, this message translates to:
  /// **'Enter {min}–{max} months'**
  String forecastHorizonRangeError(int min, int max);

  /// No description provided for @forecastLowestPoint.
  ///
  /// In en, this message translates to:
  /// **'Lowest point'**
  String get forecastLowestPoint;

  /// No description provided for @forecastDaysBelow.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day below {limit}} other{{days} days below {limit}}}'**
  String forecastDaysBelow(int days, String limit);

  /// No description provided for @forecastStaysAbove.
  ///
  /// In en, this message translates to:
  /// **'Stays above {limit}'**
  String forecastStaysAbove(Object limit);

  /// No description provided for @forecastLowestBelowThreshold.
  ///
  /// In en, this message translates to:
  /// **'Lowest {amount} on {date}, below your {threshold} threshold'**
  String forecastLowestBelowThreshold(
    String amount,
    String date,
    String threshold,
  );

  /// No description provided for @forecastLowestBelowZero.
  ///
  /// In en, this message translates to:
  /// **'Lowest {amount} on {date}, below zero'**
  String forecastLowestBelowZero(String amount, String date);

  /// No description provided for @forecastLowestOk.
  ///
  /// In en, this message translates to:
  /// **'Lowest {amount} on {date}'**
  String forecastLowestOk(String amount, String date);

  /// No description provided for @forecastLegendBaseline.
  ///
  /// In en, this message translates to:
  /// **'Baseline'**
  String get forecastLegendBaseline;

  /// No description provided for @forecastLegendThreshold.
  ///
  /// In en, this message translates to:
  /// **'Threshold'**
  String get forecastLegendThreshold;

  /// No description provided for @forecastLegendCombined.
  ///
  /// In en, this message translates to:
  /// **'All combined'**
  String get forecastLegendCombined;

  /// No description provided for @forecastCombinedDesc.
  ///
  /// In en, this message translates to:
  /// **'All compared scenarios applied together'**
  String get forecastCombinedDesc;

  /// No description provided for @forecastChartSummary.
  ///
  /// In en, this message translates to:
  /// **'Projected daily balance of {account} from {start} to {end}. Lowest point {amount} on {date}.'**
  String forecastChartSummary(
    String account,
    String start,
    String end,
    String amount,
    String date,
  );

  /// No description provided for @forecastChartThreshold.
  ///
  /// In en, this message translates to:
  /// **'Low-balance threshold {threshold}.'**
  String forecastChartThreshold(Object threshold);

  /// No description provided for @forecastChartScenario.
  ///
  /// In en, this message translates to:
  /// **'With {name}: lowest {amount} on {date}.'**
  String forecastChartScenario(String name, String amount, String date);

  /// No description provided for @forecastScenarios.
  ///
  /// In en, this message translates to:
  /// **'Scenarios'**
  String get forecastScenarios;

  /// No description provided for @forecastEditScenarios.
  ///
  /// In en, this message translates to:
  /// **'Edit scenarios'**
  String get forecastEditScenarios;

  /// No description provided for @forecastHideSidePanel.
  ///
  /// In en, this message translates to:
  /// **'Hide side panel'**
  String get forecastHideSidePanel;

  /// No description provided for @forecastShowSidePanel.
  ///
  /// In en, this message translates to:
  /// **'Show side panel'**
  String get forecastShowSidePanel;

  /// No description provided for @forecastNoScenarios.
  ///
  /// In en, this message translates to:
  /// **'No scenarios yet. Try a raise, a big purchase or paying off a loan early.'**
  String get forecastNoScenarios;

  /// No description provided for @forecastAddScenario.
  ///
  /// In en, this message translates to:
  /// **'Add scenario'**
  String get forecastAddScenario;

  /// No description provided for @forecastBalances.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get forecastBalances;

  /// No description provided for @forecastMonths.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get forecastMonths;

  /// No description provided for @forecastBudgetPeriods.
  ///
  /// In en, this message translates to:
  /// **'Budget periods'**
  String get forecastBudgetPeriods;

  /// No description provided for @forecastColMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get forecastColMonth;

  /// No description provided for @forecastColPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get forecastColPeriod;

  /// No description provided for @forecastColLowest.
  ///
  /// In en, this message translates to:
  /// **'Lowest'**
  String get forecastColLowest;

  /// No description provided for @forecastColEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get forecastColEnd;

  /// No description provided for @forecastColWith.
  ///
  /// In en, this message translates to:
  /// **'With {name}'**
  String forecastColWith(Object name);

  /// No description provided for @forecastPartial.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String forecastPartial(Object date);

  /// No description provided for @forecastWhatIf.
  ///
  /// In en, this message translates to:
  /// **'Can I afford it?'**
  String get forecastWhatIf;

  /// No description provided for @forecastWhatIfAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get forecastWhatIfAmount;

  /// No description provided for @forecastWhatIfDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get forecastWhatIfDate;

  /// No description provided for @forecastWhatIfAccount.
  ///
  /// In en, this message translates to:
  /// **'From account'**
  String get forecastWhatIfAccount;

  /// No description provided for @forecastWhatIfCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get forecastWhatIfCheck;

  /// No description provided for @forecastWhatIfHint.
  ///
  /// In en, this message translates to:
  /// **'Checks the forecast only. Nothing is saved.'**
  String get forecastWhatIfHint;

  /// No description provided for @forecastWhatIfQuestion.
  ///
  /// In en, this message translates to:
  /// **'Can I afford {amount} on {date} from {account}?'**
  String forecastWhatIfQuestion(String amount, String date, String account);

  /// No description provided for @forecastWhatIfYes.
  ///
  /// In en, this message translates to:
  /// **'Yes. Afterwards your lowest balance is {amount} on {date}.'**
  String forecastWhatIfYes(String amount, String date);

  /// No description provided for @forecastWhatIfTight.
  ///
  /// In en, this message translates to:
  /// **'Tight. Your balance would drop to {amount} on {date}, below your {threshold} threshold.'**
  String forecastWhatIfTight(String amount, String date, String threshold);

  /// No description provided for @forecastWhatIfNo.
  ///
  /// In en, this message translates to:
  /// **'No. Your balance would drop to {amount} on {date}.'**
  String forecastWhatIfNo(String amount, String date);

  /// No description provided for @forecastWhatIfChange.
  ///
  /// In en, this message translates to:
  /// **'{delta} compared with now'**
  String forecastWhatIfChange(Object delta);

  /// No description provided for @forecastWhatIfEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get forecastWhatIfEnterAmount;

  /// No description provided for @forecastUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming big events'**
  String get forecastUpcoming;

  /// No description provided for @forecastNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No big events in this horizon.'**
  String get forecastNoEvents;

  /// No description provided for @forecastShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get forecastShowAll;

  /// No description provided for @forecastShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get forecastShowLess;

  /// No description provided for @forecastWarnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get forecastWarnings;

  /// No description provided for @forecastWarnBelowZero.
  ///
  /// In en, this message translates to:
  /// **'{account} goes below zero on {date}'**
  String forecastWarnBelowZero(String account, String date);

  /// No description provided for @forecastWarnBelowThreshold.
  ///
  /// In en, this message translates to:
  /// **'{account} drops below {threshold} on {date}'**
  String forecastWarnBelowThreshold(
    String account,
    String threshold,
    String date,
  );

  /// No description provided for @forecastNoWarnings.
  ///
  /// In en, this message translates to:
  /// **'No account drops below its threshold.'**
  String get forecastNoWarnings;

  /// No description provided for @forecastNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts are included in the forecast yet. Add an account or turn on “Include in forecast”.'**
  String get forecastNoAccounts;

  /// No description provided for @forecastAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get forecastAddAccount;

  /// No description provided for @forecastModuleOff.
  ///
  /// In en, this message translates to:
  /// **'The forecast is turned off. You can turn it on in Settings › Navigation & modules.'**
  String get forecastModuleOff;

  /// No description provided for @forecastOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get forecastOpenSettings;

  /// No description provided for @forecastProjection.
  ///
  /// In en, this message translates to:
  /// **'Long-term projection'**
  String get forecastProjection;

  /// No description provided for @forecastEventRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get forecastEventRecurring;

  /// No description provided for @forecastEventScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get forecastEventScheduled;

  /// No description provided for @forecastEventGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal contribution'**
  String get forecastEventGoal;

  /// No description provided for @forecastEventOneOff.
  ///
  /// In en, this message translates to:
  /// **'Scenario'**
  String get forecastEventOneOff;

  /// No description provided for @forecastEventWhatIf.
  ///
  /// In en, this message translates to:
  /// **'What-if'**
  String get forecastEventWhatIf;

  /// No description provided for @forecastTransferTo.
  ///
  /// In en, this message translates to:
  /// **'To {account}'**
  String forecastTransferTo(Object account);

  /// No description provided for @forecastTransferFrom.
  ///
  /// In en, this message translates to:
  /// **'From {account}'**
  String forecastTransferFrom(Object account);

  /// No description provided for @forecastVariableNote.
  ///
  /// In en, this message translates to:
  /// **'Includes expected variable spending: {method}.'**
  String forecastVariableNote(Object method);

  /// No description provided for @forecastLoading.
  ///
  /// In en, this message translates to:
  /// **'Calculating forecast…'**
  String get forecastLoading;

  /// No description provided for @forecastProjYears.
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get forecastProjYears;

  /// No description provided for @forecastProjYearsValue.
  ///
  /// In en, this message translates to:
  /// **'{years, plural, =1{1 year} other{{years} years}}'**
  String forecastProjYearsValue(int years);

  /// No description provided for @forecastProjSource.
  ///
  /// In en, this message translates to:
  /// **'Savings from'**
  String get forecastProjSource;

  /// No description provided for @forecastProjSourceHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get forecastProjSourceHistory;

  /// No description provided for @forecastProjSourcePlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get forecastProjSourcePlan;

  /// No description provided for @forecastProjSourceHistoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Average of the last 12 months: {amount} per month'**
  String forecastProjSourceHistoryDesc(Object amount);

  /// No description provided for @forecastProjSourcePlanDesc.
  ///
  /// In en, this message translates to:
  /// **'Recurring items and expected spending: {amount} in the first month'**
  String forecastProjSourcePlanDesc(Object amount);

  /// No description provided for @forecastProjRealDesc.
  ///
  /// In en, this message translates to:
  /// **'In today\'s money (adjusted for inflation)'**
  String get forecastProjRealDesc;

  /// No description provided for @forecastProjPerYear.
  ///
  /// In en, this message translates to:
  /// **'{value} per year'**
  String forecastProjPerYear(Object value);

  /// No description provided for @forecastProjNetWorthOn.
  ///
  /// In en, this message translates to:
  /// **'Net worth on {date}'**
  String forecastProjNetWorthOn(Object date);

  /// No description provided for @forecastProjToday.
  ///
  /// In en, this message translates to:
  /// **'Today: {amount}'**
  String forecastProjToday(Object amount);

  /// No description provided for @forecastProjMilestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get forecastProjMilestones;

  /// No description provided for @forecastProjNoMilestones.
  ///
  /// In en, this message translates to:
  /// **'No milestones within this period.'**
  String get forecastProjNoMilestones;

  /// No description provided for @forecastMilestoneNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth reaches {amount}'**
  String forecastMilestoneNetWorth(Object amount);

  /// No description provided for @forecastMilestoneDebtFree.
  ///
  /// In en, this message translates to:
  /// **'Debt-free'**
  String get forecastMilestoneDebtFree;

  /// No description provided for @forecastMilestonePaidOff.
  ///
  /// In en, this message translates to:
  /// **'{account} paid off'**
  String forecastMilestonePaidOff(Object account);

  /// No description provided for @forecastMilestoneGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal reached: {goal}'**
  String forecastMilestoneGoal(Object goal);

  /// No description provided for @forecastProjChartSummary.
  ///
  /// In en, this message translates to:
  /// **'Projected net worth from {start} to {end}: {startAmount} now, {endAmount} at the end.'**
  String forecastProjChartSummary(
    String start,
    String end,
    String startAmount,
    String endAmount,
  );

  /// No description provided for @forecastProjChartMilestones.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No milestones.} =1{1 milestone.} other{{count} milestones.}}'**
  String forecastProjChartMilestones(int count);

  /// No description provided for @forecastProjAssumptions.
  ///
  /// In en, this message translates to:
  /// **'Assumptions'**
  String get forecastProjAssumptions;

  /// No description provided for @forecastProjAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get forecastProjAssets;

  /// No description provided for @forecastProjDebts.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get forecastProjDebts;

  /// No description provided for @forecastProjNominal.
  ///
  /// In en, this message translates to:
  /// **'Nominal'**
  String get forecastProjNominal;

  /// No description provided for @forecastProjReal.
  ///
  /// In en, this message translates to:
  /// **'Real'**
  String get forecastProjReal;

  /// No description provided for @forecastProjNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts are included in net worth yet.'**
  String get forecastProjNoAccounts;

  /// No description provided for @goalsNew.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get goalsNew;

  /// No description provided for @goalsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get goalsEdit;

  /// No description provided for @goalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No savings goals yet. Set one to see how much to put aside each period.'**
  String get goalsEmpty;

  /// No description provided for @goalsNoActive.
  ///
  /// In en, this message translates to:
  /// **'All goals are archived.'**
  String get goalsNoActive;

  /// No description provided for @goalsByPriority.
  ///
  /// In en, this message translates to:
  /// **'By priority · drag to reorder'**
  String get goalsByPriority;

  /// No description provided for @goalsArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived ({count})'**
  String goalsArchived(int count);

  /// No description provided for @goalsShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get goalsShow;

  /// No description provided for @goalsHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get goalsHide;

  /// No description provided for @goalsSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select a goal to see its details.'**
  String get goalsSelectHint;

  /// No description provided for @goalsReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached'**
  String get goalsReached;

  /// No description provided for @goalsRequiredPerPeriod.
  ///
  /// In en, this message translates to:
  /// **'Needs {amount} per period until {date}'**
  String goalsRequiredPerPeriod(String amount, String date);

  /// No description provided for @goalsProjected.
  ///
  /// In en, this message translates to:
  /// **'At this pace: {date}'**
  String goalsProjected(String date);

  /// No description provided for @goalsNoPace.
  ///
  /// In en, this message translates to:
  /// **'Set a planned contribution to see when you get there.'**
  String get goalsNoPace;

  /// No description provided for @goalsOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get goalsOnTrack;

  /// No description provided for @goalsBehind.
  ///
  /// In en, this message translates to:
  /// **'Behind'**
  String get goalsBehind;

  /// No description provided for @goalsOfTarget.
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String goalsOfTarget(String amount);

  /// No description provided for @goalsAddContribution.
  ///
  /// In en, this message translates to:
  /// **'Add contribution'**
  String get goalsAddContribution;

  /// No description provided for @goalsReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to change priority'**
  String get goalsReorder;

  /// No description provided for @goalsSemanticProgress.
  ///
  /// In en, this message translates to:
  /// **'{saved} of {target} saved'**
  String goalsSemanticProgress(String saved, String target);

  /// No description provided for @goalsDeposit.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get goalsDeposit;

  /// No description provided for @goalsWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get goalsWithdraw;

  /// No description provided for @goalsAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get goalsAmountInvalid;

  /// No description provided for @goalsModuleOff.
  ///
  /// In en, this message translates to:
  /// **'Goals are switched off in Settings › Navigation & modules.'**
  String get goalsModuleOff;

  /// No description provided for @goalsNotFound.
  ///
  /// In en, this message translates to:
  /// **'This goal no longer exists.'**
  String get goalsNotFound;

  /// No description provided for @goalsSaved.
  ///
  /// In en, this message translates to:
  /// **'Goal saved'**
  String get goalsSaved;

  /// No description provided for @goalsDetails.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goalsDetails;

  /// No description provided for @goalsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get goalsName;

  /// No description provided for @goalsNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get goalsNameRequired;

  /// No description provided for @goalsTarget.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get goalsTarget;

  /// No description provided for @goalsTargetRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a target above 0'**
  String get goalsTargetRequired;

  /// No description provided for @goalsTargetDate.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get goalsTargetDate;

  /// No description provided for @goalsNoTargetDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get goalsNoTargetDate;

  /// No description provided for @goalsLinkedAccount.
  ///
  /// In en, this message translates to:
  /// **'Linked account'**
  String get goalsLinkedAccount;

  /// No description provided for @goalsNoAccount.
  ///
  /// In en, this message translates to:
  /// **'None – track manually'**
  String get goalsNoAccount;

  /// No description provided for @goalsLinkedHelp.
  ///
  /// In en, this message translates to:
  /// **'Progress follows the account balance; the pace comes from its last 3–6 months.'**
  String get goalsLinkedHelp;

  /// No description provided for @goalsSavedSoFar.
  ///
  /// In en, this message translates to:
  /// **'Saved so far'**
  String get goalsSavedSoFar;

  /// No description provided for @goalsPlannedContribution.
  ///
  /// In en, this message translates to:
  /// **'Planned contribution per period'**
  String get goalsPlannedContribution;

  /// No description provided for @goalsPlannedContributionHelp.
  ///
  /// In en, this message translates to:
  /// **'Used for the projected date when there is no account history.'**
  String get goalsPlannedContributionHelp;

  /// No description provided for @goalsArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get goalsArchive;

  /// No description provided for @goalsUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get goalsUnarchive;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importTitle;

  /// No description provided for @importStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String importStepOf(int current, int total);

  /// No description provided for @importStepSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get importStepSource;

  /// No description provided for @importStepSheets.
  ///
  /// In en, this message translates to:
  /// **'Sheets'**
  String get importStepSheets;

  /// No description provided for @importStepStructure.
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get importStepStructure;

  /// No description provided for @importStepMapping.
  ///
  /// In en, this message translates to:
  /// **'Map columns'**
  String get importStepMapping;

  /// No description provided for @importStepFormats.
  ///
  /// In en, this message translates to:
  /// **'Formats'**
  String get importStepFormats;

  /// No description provided for @importStepValues.
  ///
  /// In en, this message translates to:
  /// **'Categories & accounts'**
  String get importStepValues;

  /// No description provided for @importStepTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get importStepTransfers;

  /// No description provided for @importStepDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Duplicates'**
  String get importStepDuplicates;

  /// No description provided for @importStepSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get importStepSummary;

  /// No description provided for @importNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next: {step}'**
  String importNextStep(String step);

  /// No description provided for @importProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile: {name}'**
  String importProfileLabel(String name);

  /// No description provided for @importWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get importWorking;

  /// No description provided for @importHistory.
  ///
  /// In en, this message translates to:
  /// **'Import history'**
  String get importHistory;

  /// No description provided for @importCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the import?'**
  String get importCancelTitle;

  /// No description provided for @importCancelMessage.
  ///
  /// In en, this message translates to:
  /// **'Your choices for this import are lost.'**
  String get importCancelMessage;

  /// No description provided for @importCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get importCancelConfirm;

  /// No description provided for @importSourceIntro.
  ///
  /// In en, this message translates to:
  /// **'Import your spreadsheet history or bank exports. Several files can be imported in one batch.'**
  String get importSourceIntro;

  /// No description provided for @importPickFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get importPickFiles;

  /// No description provided for @importPickFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Excel (.xlsx, .xlsm, .xls), CSV or TSV'**
  String get importPickFilesHint;

  /// No description provided for @importPasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste from a spreadsheet'**
  String get importPasteTitle;

  /// No description provided for @importPasteHint.
  ///
  /// In en, this message translates to:
  /// **'Select rows in Excel, copy them and paste them here.'**
  String get importPasteHint;

  /// No description provided for @importPasteButton.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get importPasteButton;

  /// No description provided for @importPasteAdd.
  ///
  /// In en, this message translates to:
  /// **'Use these rows'**
  String get importPasteAdd;

  /// No description provided for @importPasteField.
  ///
  /// In en, this message translates to:
  /// **'Pasted rows'**
  String get importPasteField;

  /// No description provided for @importPasteEmpty.
  ///
  /// In en, this message translates to:
  /// **'The clipboard holds no text.'**
  String get importPasteEmpty;

  /// No description provided for @importFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files in this import'**
  String get importFilesTitle;

  /// No description provided for @importFileSheets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sheet} other{{count} sheets}}'**
  String importFileSheets(int count);

  /// No description provided for @importRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}}'**
  String importRows(int count);

  /// No description provided for @importFileCsvInfo.
  ///
  /// In en, this message translates to:
  /// **'{encoding} · delimiter {delimiter}'**
  String importFileCsvInfo(String encoding, String delimiter);

  /// No description provided for @importRemoveFile.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get importRemoveFile;

  /// No description provided for @importCsvOptions.
  ///
  /// In en, this message translates to:
  /// **'Reading options'**
  String get importCsvOptions;

  /// No description provided for @importEncoding.
  ///
  /// In en, this message translates to:
  /// **'Encoding'**
  String get importEncoding;

  /// No description provided for @importAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get importAuto;

  /// No description provided for @importDelimiter.
  ///
  /// In en, this message translates to:
  /// **'Delimiter'**
  String get importDelimiter;

  /// No description provided for @importQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote character'**
  String get importQuote;

  /// No description provided for @importTab.
  ///
  /// In en, this message translates to:
  /// **'Tab'**
  String get importTab;

  /// No description provided for @importErrOds.
  ///
  /// In en, this message translates to:
  /// **'OpenDocument spreadsheets (.ods) can\'t be read. Open the file in LibreOffice Calc or Excel, save it as Excel workbook (.xlsx) and import that file.'**
  String get importErrOds;

  /// No description provided for @importErrNumbers.
  ///
  /// In en, this message translates to:
  /// **'Apple Numbers files can\'t be read. In Numbers choose File › Export To › Excel and import the .xlsx file.'**
  String get importErrNumbers;

  /// No description provided for @importErrEncrypted.
  ///
  /// In en, this message translates to:
  /// **'This workbook is password-protected. Remove the password in Excel (File › Info › Protect Workbook), save it and try again.'**
  String get importErrEncrypted;

  /// No description provided for @importErrNotSpreadsheet.
  ///
  /// In en, this message translates to:
  /// **'This file holds no table that can be imported.'**
  String get importErrNotSpreadsheet;

  /// No description provided for @importErrCorrupt.
  ///
  /// In en, this message translates to:
  /// **'The file could not be read. It may be damaged or in an unsupported format.'**
  String get importErrCorrupt;

  /// No description provided for @importErrEmpty.
  ///
  /// In en, this message translates to:
  /// **'The file is empty.'**
  String get importErrEmpty;

  /// No description provided for @importProfileUse.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get importProfileUse;

  /// No description provided for @importProfileNone.
  ///
  /// In en, this message translates to:
  /// **'No profile – detect everything'**
  String get importProfileNone;

  /// No description provided for @importProfileLoadFile.
  ///
  /// In en, this message translates to:
  /// **'Load profile file'**
  String get importProfileLoadFile;

  /// No description provided for @importProfileInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file is not an import profile.'**
  String get importProfileInvalid;

  /// No description provided for @importProfileHint.
  ///
  /// In en, this message translates to:
  /// **'A profile repeats every choice of an earlier import.'**
  String get importProfileHint;

  /// No description provided for @importSheetsIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose the sheets to import and where their account comes from.'**
  String get importSheetsIntro;

  /// No description provided for @importSheetHidden.
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get importSheetHidden;

  /// No description provided for @importSheetNoData.
  ///
  /// In en, this message translates to:
  /// **'No transactions found'**
  String get importSheetNoData;

  /// No description provided for @importAccountSource.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get importAccountSource;

  /// No description provided for @importAccountFixed.
  ///
  /// In en, this message translates to:
  /// **'One account'**
  String get importAccountFixed;

  /// No description provided for @importAccountColumn.
  ///
  /// In en, this message translates to:
  /// **'From a column'**
  String get importAccountColumn;

  /// No description provided for @importAccountSheetName.
  ///
  /// In en, this message translates to:
  /// **'Sheet name'**
  String get importAccountSheetName;

  /// No description provided for @importAccountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get importAccountName;

  /// No description provided for @importAccountNameHint.
  ///
  /// In en, this message translates to:
  /// **'Existing or new account'**
  String get importAccountNameHint;

  /// No description provided for @importYear.
  ///
  /// In en, this message translates to:
  /// **'Year for dates without year'**
  String get importYear;

  /// No description provided for @importYearNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get importYearNone;

  /// No description provided for @importStructureIntro.
  ///
  /// In en, this message translates to:
  /// **'Rows above the header (titles, bank details), sum rows and empty rows are skipped.'**
  String get importStructureIntro;

  /// No description provided for @importHeaderRow.
  ///
  /// In en, this message translates to:
  /// **'Header row'**
  String get importHeaderRow;

  /// No description provided for @importHeaderRows.
  ///
  /// In en, this message translates to:
  /// **'Header rows'**
  String get importHeaderRows;

  /// No description provided for @importNoHeader.
  ///
  /// In en, this message translates to:
  /// **'No header'**
  String get importNoHeader;

  /// No description provided for @importFirstDataRow.
  ///
  /// In en, this message translates to:
  /// **'First data row'**
  String get importFirstDataRow;

  /// No description provided for @importLastDataRow.
  ///
  /// In en, this message translates to:
  /// **'Last data row'**
  String get importLastDataRow;

  /// No description provided for @importUntilEnd.
  ///
  /// In en, this message translates to:
  /// **'Until the end'**
  String get importUntilEnd;

  /// No description provided for @importRowFilters.
  ///
  /// In en, this message translates to:
  /// **'Row filters'**
  String get importRowFilters;

  /// No description provided for @importSkipPatterns.
  ///
  /// In en, this message translates to:
  /// **'Skip sum rows starting with'**
  String get importSkipPatterns;

  /// No description provided for @importSkipPatternsHint.
  ///
  /// In en, this message translates to:
  /// **'Separate with commas; /…/ is a regular expression'**
  String get importSkipPatternsHint;

  /// No description provided for @importSkipWithoutDate.
  ///
  /// In en, this message translates to:
  /// **'Skip rows without a date'**
  String get importSkipWithoutDate;

  /// No description provided for @importSkipZero.
  ///
  /// In en, this message translates to:
  /// **'Skip rows without an amount'**
  String get importSkipZero;

  /// No description provided for @importRowData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get importRowData;

  /// No description provided for @importRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get importRowTitle;

  /// No description provided for @importRowHeader.
  ///
  /// In en, this message translates to:
  /// **'Header'**
  String get importRowHeader;

  /// No description provided for @importRowEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get importRowEmpty;

  /// No description provided for @importRowSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Sum row'**
  String get importRowSubtotal;

  /// No description provided for @importRowNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get importRowNoDate;

  /// No description provided for @importRowNoAmount.
  ///
  /// In en, this message translates to:
  /// **'No amount'**
  String get importRowNoAmount;

  /// No description provided for @importRowAfterEnd.
  ///
  /// In en, this message translates to:
  /// **'After the end'**
  String get importRowAfterEnd;

  /// No description provided for @importRowInvalid.
  ///
  /// In en, this message translates to:
  /// **'Unreadable'**
  String get importRowInvalid;

  /// No description provided for @importRowStats.
  ///
  /// In en, this message translates to:
  /// **'{data} data rows · {skipped} skipped'**
  String importRowStats(int data, int skipped);

  /// No description provided for @importPreviewMore.
  ///
  /// In en, this message translates to:
  /// **'Showing the first {shown} of {total} rows'**
  String importPreviewMore(int shown, int total);

  /// No description provided for @importSheetPicker.
  ///
  /// In en, this message translates to:
  /// **'Sheet'**
  String get importSheetPicker;

  /// No description provided for @importSheetInfo.
  ///
  /// In en, this message translates to:
  /// **'{file} · sheet “{sheet}”'**
  String importSheetInfo(String file, String sheet);

  /// No description provided for @importInfoHeaderRow.
  ///
  /// In en, this message translates to:
  /// **'header in row {row}'**
  String importInfoHeaderRow(int row);

  /// No description provided for @importInfoNoHeader.
  ///
  /// In en, this message translates to:
  /// **'no header'**
  String get importInfoNoHeader;

  /// No description provided for @importInfoSubtotals.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subtotal row skipped} other{{count} subtotal rows skipped}}'**
  String importInfoSubtotals(int count);

  /// No description provided for @importAmountMode.
  ///
  /// In en, this message translates to:
  /// **'Amounts are written as'**
  String get importAmountMode;

  /// No description provided for @importAmountSigned.
  ///
  /// In en, this message translates to:
  /// **'One signed'**
  String get importAmountSigned;

  /// No description provided for @importAmountDebitCredit.
  ///
  /// In en, this message translates to:
  /// **'Out + In'**
  String get importAmountDebitCredit;

  /// No description provided for @importAmountWithType.
  ///
  /// In en, this message translates to:
  /// **'+ Type col.'**
  String get importAmountWithType;

  /// No description provided for @importInvertSign.
  ///
  /// In en, this message translates to:
  /// **'Expenses are written as positive numbers'**
  String get importInvertSign;

  /// No description provided for @importTypeNegative.
  ///
  /// In en, this message translates to:
  /// **'Type values for money out'**
  String get importTypeNegative;

  /// No description provided for @importTypePositive.
  ///
  /// In en, this message translates to:
  /// **'Type values for money in'**
  String get importTypePositive;

  /// No description provided for @importCategorySeparator.
  ///
  /// In en, this message translates to:
  /// **'Category separator'**
  String get importCategorySeparator;

  /// No description provided for @importTagSeparator.
  ///
  /// In en, this message translates to:
  /// **'Tag separator'**
  String get importTagSeparator;

  /// No description provided for @importSeparatorNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get importSeparatorNone;

  /// No description provided for @importSeparatorSpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get importSeparatorSpace;

  /// No description provided for @importTargetIgnore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get importTargetIgnore;

  /// No description provided for @importTargetDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get importTargetDate;

  /// No description provided for @importTargetValueDate.
  ///
  /// In en, this message translates to:
  /// **'Value date'**
  String get importTargetValueDate;

  /// No description provided for @importTargetAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get importTargetAmount;

  /// No description provided for @importTargetAmountAbs.
  ///
  /// In en, this message translates to:
  /// **'Amount (without sign)'**
  String get importTargetAmountAbs;

  /// No description provided for @importTargetDebit.
  ///
  /// In en, this message translates to:
  /// **'Amount out (debit)'**
  String get importTargetDebit;

  /// No description provided for @importTargetCredit.
  ///
  /// In en, this message translates to:
  /// **'Amount in (credit)'**
  String get importTargetCredit;

  /// No description provided for @importTargetAmountType.
  ///
  /// In en, this message translates to:
  /// **'Type (in/out)'**
  String get importTargetAmountType;

  /// No description provided for @importTargetPayee.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get importTargetPayee;

  /// No description provided for @importTargetNote.
  ///
  /// In en, this message translates to:
  /// **'Description / note'**
  String get importTargetNote;

  /// No description provided for @importTargetCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get importTargetCategory;

  /// No description provided for @importTargetCategorySub.
  ///
  /// In en, this message translates to:
  /// **'Category › Sub (“{separator}”)'**
  String importTargetCategorySub(String separator);

  /// No description provided for @importTargetSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Subcategory'**
  String get importTargetSubcategory;

  /// No description provided for @importTargetAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get importTargetAccount;

  /// No description provided for @importTargetTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get importTargetTags;

  /// No description provided for @importTargetStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get importTargetStatus;

  /// No description provided for @importTargetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom field: {name}'**
  String importTargetCustom(String name);

  /// No description provided for @importTargetBalance.
  ///
  /// In en, this message translates to:
  /// **'Running balance (check)'**
  String get importTargetBalance;

  /// No description provided for @importColumn.
  ///
  /// In en, this message translates to:
  /// **'Column {letter}'**
  String importColumn(String letter);

  /// No description provided for @importBalanceCheck.
  ///
  /// In en, this message translates to:
  /// **'Balance check: {matched} of {checked} rows match column {column}'**
  String importBalanceCheck(int matched, int checked, String column);

  /// No description provided for @importBadValues.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 value can\'t be read} other{{count} values can\'t be read}} (rows {rows})'**
  String importBadValues(int count, String rows);

  /// No description provided for @importMismatches.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 balance mismatch} other{{count} balance mismatches}} (rows {rows})'**
  String importMismatches(int count, String rows);

  /// No description provided for @importApplyToSimilar.
  ///
  /// In en, this message translates to:
  /// **'Use for all sheets with these columns'**
  String get importApplyToSimilar;

  /// No description provided for @importAppliedToSimilar.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No other sheet has these columns} =1{Applied to 1 more sheet} other{Applied to {count} more sheets}}'**
  String importAppliedToSimilar(int count);

  /// No description provided for @importNeedDateAmount.
  ///
  /// In en, this message translates to:
  /// **'Map a date and an amount column in every sheet to continue.'**
  String get importNeedDateAmount;

  /// No description provided for @importInvalidCell.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be read: {value}'**
  String importInvalidCell(String value);

  /// No description provided for @importFormatsIntro.
  ///
  /// In en, this message translates to:
  /// **'Formats are detected per column. Change them when values are read wrongly.'**
  String get importFormatsIntro;

  /// No description provided for @importDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get importDateFormat;

  /// No description provided for @importNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format'**
  String get importNumberFormat;

  /// No description provided for @importDetected.
  ///
  /// In en, this message translates to:
  /// **'Detected: {format}'**
  String importDetected(String format);

  /// No description provided for @importDateSerial.
  ///
  /// In en, this message translates to:
  /// **'Excel serial number (45000)'**
  String get importDateSerial;

  /// No description provided for @importDateDmy.
  ///
  /// In en, this message translates to:
  /// **'Day first (31.12.2024)'**
  String get importDateDmy;

  /// No description provided for @importDateMdy.
  ///
  /// In en, this message translates to:
  /// **'Month first (12/31/2024)'**
  String get importDateMdy;

  /// No description provided for @importDateYmd.
  ///
  /// In en, this message translates to:
  /// **'ISO (2024-12-31)'**
  String get importDateYmd;

  /// No description provided for @importDateCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact (20241231)'**
  String get importDateCompact;

  /// No description provided for @importDateMonthName.
  ///
  /// In en, this message translates to:
  /// **'Month name (31 Dec 2024)'**
  String get importDateMonthName;

  /// No description provided for @importDateCells.
  ///
  /// In en, this message translates to:
  /// **'Date cells'**
  String get importDateCells;

  /// No description provided for @importNumberDe.
  ///
  /// In en, this message translates to:
  /// **'1.234,56'**
  String get importNumberDe;

  /// No description provided for @importNumberEn.
  ///
  /// In en, this message translates to:
  /// **'1,234.56'**
  String get importNumberEn;

  /// No description provided for @importNumberSpace.
  ///
  /// In en, this message translates to:
  /// **'1 234,56'**
  String get importNumberSpace;

  /// No description provided for @importSamples.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get importSamples;

  /// No description provided for @importIssuesTitle.
  ///
  /// In en, this message translates to:
  /// **'Values that can\'t be read'**
  String get importIssuesTitle;

  /// No description provided for @importNoIssues.
  ///
  /// In en, this message translates to:
  /// **'All values can be read.'**
  String get importNoIssues;

  /// No description provided for @importIssueAt.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, column {column}'**
  String importIssueAt(int row, String column);

  /// No description provided for @importIssueBadDate.
  ///
  /// In en, this message translates to:
  /// **'Not a date'**
  String get importIssueBadDate;

  /// No description provided for @importIssueMissingDate.
  ///
  /// In en, this message translates to:
  /// **'Date missing'**
  String get importIssueMissingDate;

  /// No description provided for @importIssueBadValueDate.
  ///
  /// In en, this message translates to:
  /// **'Value date not readable (ignored)'**
  String get importIssueBadValueDate;

  /// No description provided for @importIssueBadAmount.
  ///
  /// In en, this message translates to:
  /// **'Not an amount'**
  String get importIssueBadAmount;

  /// No description provided for @importIssueMissingAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount missing'**
  String get importIssueMissingAmount;

  /// No description provided for @importIssueBadType.
  ///
  /// In en, this message translates to:
  /// **'Unknown type value'**
  String get importIssueBadType;

  /// No description provided for @importIssueBadBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance not readable (not checked)'**
  String get importIssueBadBalance;

  /// No description provided for @importIssueBadStatus.
  ///
  /// In en, this message translates to:
  /// **'Unknown status (ignored)'**
  String get importIssueBadStatus;

  /// No description provided for @importIssueBadCustomField.
  ///
  /// In en, this message translates to:
  /// **'Custom field value not readable'**
  String get importIssueBadCustomField;

  /// No description provided for @importIssueMissingAccount.
  ///
  /// In en, this message translates to:
  /// **'No account'**
  String get importIssueMissingAccount;

  /// No description provided for @importIssueYearMismatch.
  ///
  /// In en, this message translates to:
  /// **'Date outside the sheet\'s year'**
  String get importIssueYearMismatch;

  /// No description provided for @importMoreIssues.
  ///
  /// In en, this message translates to:
  /// **'and {count} more'**
  String importMoreIssues(int count);

  /// No description provided for @importAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get importAccountsTitle;

  /// No description provided for @importCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get importCategoriesTitle;

  /// No description provided for @importValuesIntro.
  ///
  /// In en, this message translates to:
  /// **'Each value from the sheets goes to an existing entry or creates a new one.'**
  String get importValuesIntro;

  /// No description provided for @importValueRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}} · {sum}'**
  String importValueRows(int count, String sum);

  /// No description provided for @importExisting.
  ///
  /// In en, this message translates to:
  /// **'Existing'**
  String get importExisting;

  /// No description provided for @importCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get importCreateNew;

  /// No description provided for @importNoCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get importNoCategory;

  /// No description provided for @importAsTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get importAsTransfer;

  /// No description provided for @importTransferTo.
  ///
  /// In en, this message translates to:
  /// **'Transfer to account'**
  String get importTransferTo;

  /// No description provided for @importNewAccountName.
  ///
  /// In en, this message translates to:
  /// **'New account “{name}”'**
  String importNewAccountName(String name);

  /// No description provided for @importNewCategoryName.
  ///
  /// In en, this message translates to:
  /// **'New category “{name}”'**
  String importNewCategoryName(String name);

  /// No description provided for @importChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get importChoose;

  /// No description provided for @importSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggestion: {name}'**
  String importSuggestion(String name);

  /// No description provided for @importAccountType.
  ///
  /// In en, this message translates to:
  /// **'Account type'**
  String get importAccountType;

  /// No description provided for @importCategoryKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get importCategoryKind;

  /// No description provided for @importNoCategoryColumn.
  ///
  /// In en, this message translates to:
  /// **'The sheets have no category column. Rules and the transaction list can categorise later.'**
  String get importNoCategoryColumn;

  /// No description provided for @importAccTypeChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get importAccTypeChecking;

  /// No description provided for @importAccTypeSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get importAccTypeSavings;

  /// No description provided for @importAccTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get importAccTypeCash;

  /// No description provided for @importAccTypeCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get importAccTypeCreditCard;

  /// No description provided for @importAccTypeInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get importAccTypeInvestment;

  /// No description provided for @importAccTypeLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get importAccTypeLoan;

  /// No description provided for @importAccTypeOtherAsset.
  ///
  /// In en, this message translates to:
  /// **'Other asset'**
  String get importAccTypeOtherAsset;

  /// No description provided for @importAccTypeOtherLiability.
  ///
  /// In en, this message translates to:
  /// **'Other liability'**
  String get importAccTypeOtherLiability;

  /// No description provided for @importTransfersIntro.
  ///
  /// In en, this message translates to:
  /// **'Money that left one account and arrived in another is merged into one transfer.'**
  String get importTransfersIntro;

  /// No description provided for @importDetectTransfers.
  ///
  /// In en, this message translates to:
  /// **'Detect transfers'**
  String get importDetectTransfers;

  /// No description provided for @importTransferWindow.
  ///
  /// In en, this message translates to:
  /// **'Maximum days apart'**
  String get importTransferWindow;

  /// No description provided for @importDaysApart.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{same day} =1{1 day apart} other{{days} days apart}}'**
  String importDaysApart(int days);

  /// No description provided for @importTransfersNone.
  ///
  /// In en, this message translates to:
  /// **'No matching pairs found.'**
  String get importTransfersNone;

  /// No description provided for @importTransfersCount.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} pairs merged'**
  String importTransfersCount(int selected, int total);

  /// No description provided for @importMergeAll.
  ///
  /// In en, this message translates to:
  /// **'Merge all'**
  String get importMergeAll;

  /// No description provided for @importMergeNone.
  ///
  /// In en, this message translates to:
  /// **'Merge none'**
  String get importMergeNone;

  /// No description provided for @importDuplicatesIntro.
  ///
  /// In en, this message translates to:
  /// **'Rows with the same date, amount and payee/note as an existing transaction are skipped unless you include them.'**
  String get importDuplicatesIntro;

  /// No description provided for @importIncremental.
  ///
  /// In en, this message translates to:
  /// **'Only import rows added since the last import of this file or profile'**
  String get importIncremental;

  /// No description provided for @importDupExisting.
  ///
  /// In en, this message translates to:
  /// **'Already in the app'**
  String get importDupExisting;

  /// No description provided for @importDupBatch.
  ///
  /// In en, this message translates to:
  /// **'Twice in this import'**
  String get importDupBatch;

  /// No description provided for @importDupAlready.
  ///
  /// In en, this message translates to:
  /// **'Imported before'**
  String get importDupAlready;

  /// No description provided for @importDupNone.
  ///
  /// In en, this message translates to:
  /// **'No duplicates found.'**
  String get importDupNone;

  /// No description provided for @importDupSkipAll.
  ///
  /// In en, this message translates to:
  /// **'Skip all'**
  String get importDupSkipAll;

  /// No description provided for @importDupImportAll.
  ///
  /// In en, this message translates to:
  /// **'Import all'**
  String get importDupImportAll;

  /// No description provided for @importDupIncluded.
  ///
  /// In en, this message translates to:
  /// **'{included} of {total} included'**
  String importDupIncluded(int included, int total);

  /// No description provided for @importAlreadyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row was imported before and is skipped.} other{{count} rows were imported before and are skipped.}}'**
  String importAlreadyCount(int count);

  /// No description provided for @importSummaryReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to import'**
  String get importSummaryReady;

  /// No description provided for @importSummaryTransactions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String importSummaryTransactions(int count);

  /// No description provided for @importSummaryTransfers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{incl. 1 transfer} other{incl. {count} transfers}}'**
  String importSummaryTransfers(int count);

  /// No description provided for @importSummarySkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} duplicates skipped'**
  String importSummarySkipped(int count);

  /// No description provided for @importSummaryAlready.
  ///
  /// In en, this message translates to:
  /// **'{count} already imported'**
  String importSummaryAlready(int count);

  /// No description provided for @importSummaryInvalid.
  ///
  /// In en, this message translates to:
  /// **'{count} unreadable rows'**
  String importSummaryInvalid(int count);

  /// No description provided for @importSummaryRules.
  ///
  /// In en, this message translates to:
  /// **'{count} categorised by rules'**
  String importSummaryRules(int count);

  /// No description provided for @importSummaryNew.
  ///
  /// In en, this message translates to:
  /// **'New: {accounts} accounts · {categories} categories · {tags} tags'**
  String importSummaryNew(int accounts, int categories, int tags);

  /// No description provided for @importResultingBalances.
  ///
  /// In en, this message translates to:
  /// **'Resulting balances'**
  String get importResultingBalances;

  /// No description provided for @importByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get importByCategory;

  /// No description provided for @importStartsAt.
  ///
  /// In en, this message translates to:
  /// **'Starts at {amount}'**
  String importStartsAt(String amount);

  /// No description provided for @importMatchesSheet.
  ///
  /// In en, this message translates to:
  /// **'Matches the sheet'**
  String get importMatchesSheet;

  /// No description provided for @importSheetSays.
  ///
  /// In en, this message translates to:
  /// **'Sheet: {amount}'**
  String importSheetSays(String amount);

  /// No description provided for @importNewBadge.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get importNewBadge;

  /// No description provided for @importUncategorised.
  ///
  /// In en, this message translates to:
  /// **'Uncategorised'**
  String get importUncategorised;

  /// No description provided for @importWarnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get importWarnings;

  /// No description provided for @importWarnInvalid.
  ///
  /// In en, this message translates to:
  /// **'{count} rows can\'t be read and will not be imported.'**
  String importWarnInvalid(int count);

  /// No description provided for @importWarnMismatch.
  ///
  /// In en, this message translates to:
  /// **'{count} running-balance mismatches in {account}.'**
  String importWarnMismatch(int count, String account);

  /// No description provided for @importWarnFormulas.
  ///
  /// In en, this message translates to:
  /// **'{count} formula cells have no saved result. Open the file in Excel, save it and import again.'**
  String importWarnFormulas(int count);

  /// No description provided for @importWarnYear.
  ///
  /// In en, this message translates to:
  /// **'{count} dates lie outside their sheet\'s year.'**
  String importWarnYear(int count);

  /// No description provided for @importWarnUncategorised.
  ///
  /// In en, this message translates to:
  /// **'{count} transactions have no category.'**
  String importWarnUncategorised(int count);

  /// No description provided for @importWarnDuplicates.
  ///
  /// In en, this message translates to:
  /// **'{count} possible duplicates will be imported.'**
  String importWarnDuplicates(int count);

  /// No description provided for @importApplyRules.
  ///
  /// In en, this message translates to:
  /// **'Run rules on rows without a category'**
  String get importApplyRules;

  /// No description provided for @importSetOpening.
  ///
  /// In en, this message translates to:
  /// **'Set opening balances of new accounts from the running balance'**
  String get importSetOpening;

  /// No description provided for @importSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save these choices as profile'**
  String get importSaveProfile;

  /// No description provided for @importProfileName.
  ///
  /// In en, this message translates to:
  /// **'Profile name'**
  String get importProfileName;

  /// No description provided for @importUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Update profile “{name}”'**
  String importUpdateProfile(String name);

  /// No description provided for @importCommit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to import} =1{Import 1 transaction} other{Import {count} transactions}}'**
  String importCommit(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'The import failed; nothing was written. {message}'**
  String importFailed(String message);

  /// No description provided for @importDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get importDoneTitle;

  /// No description provided for @importDoneMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction was imported.} other{{count} transactions were imported.}}'**
  String importDoneMessage(int count);

  /// No description provided for @importShowTransactions.
  ///
  /// In en, this message translates to:
  /// **'Show transactions'**
  String get importShowTransactions;

  /// No description provided for @importAgain.
  ///
  /// In en, this message translates to:
  /// **'Start another import'**
  String get importAgain;

  /// No description provided for @importUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo import'**
  String get importUndo;

  /// No description provided for @importUndone.
  ///
  /// In en, this message translates to:
  /// **'Import undone'**
  String get importUndone;

  /// No description provided for @importHistoryTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get importHistoryTab;

  /// No description provided for @importProfilesTab.
  ///
  /// In en, this message translates to:
  /// **'Profiles'**
  String get importProfilesTab;

  /// No description provided for @importHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No imports yet.'**
  String get importHistoryEmpty;

  /// No description provided for @importNew.
  ///
  /// In en, this message translates to:
  /// **'New import'**
  String get importNew;

  /// No description provided for @importHistoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String importHistoryCount(int count);

  /// No description provided for @importHistoryLive.
  ///
  /// In en, this message translates to:
  /// **'{live} of {total} still present'**
  String importHistoryLive(int live, int total);

  /// No description provided for @importHistoryUndone.
  ///
  /// In en, this message translates to:
  /// **'Undone on {date}'**
  String importHistoryUndone(String date);

  /// No description provided for @importHistoryUndoTitle.
  ///
  /// In en, this message translates to:
  /// **'Undo this import?'**
  String get importHistoryUndoTitle;

  /// No description provided for @importHistoryUndoMessage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The transaction of this import is deleted.} other{All {count} transactions of this import are deleted.}} Accounts, categories and tags it created are removed when nothing else uses them.'**
  String importHistoryUndoMessage(int count);

  /// No description provided for @importHistoryUndoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo import'**
  String get importHistoryUndoAction;

  /// No description provided for @importProfilesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No profiles yet. Save one in the last step of an import.'**
  String get importProfilesEmpty;

  /// No description provided for @importProfileExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get importProfileExport;

  /// No description provided for @importProfileRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get importProfileRename;

  /// No description provided for @importProfileExported.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get importProfileExported;

  /// No description provided for @importProfileImported.
  ///
  /// In en, this message translates to:
  /// **'Profile imported'**
  String get importProfileImported;

  /// No description provided for @importProfileStart.
  ///
  /// In en, this message translates to:
  /// **'Import with this profile'**
  String get importProfileStart;

  /// No description provided for @onbDefaultChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking account'**
  String get onbDefaultChecking;

  /// No description provided for @onbStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onbStepOf(int current, int total);

  /// No description provided for @onbGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onbGetStarted;

  /// No description provided for @onbSetUpLock.
  ///
  /// In en, this message translates to:
  /// **'Set up app lock'**
  String get onbSetUpLock;

  /// No description provided for @onbSkipFinish.
  ///
  /// In en, this message translates to:
  /// **'Not now, finish'**
  String get onbSkipFinish;

  /// No description provided for @onbTagline.
  ///
  /// In en, this message translates to:
  /// **'Your money, on your device. Record, track, plan and project — without a cloud account.'**
  String get onbTagline;

  /// No description provided for @onbPointRecord.
  ///
  /// In en, this message translates to:
  /// **'Log a transaction in seconds'**
  String get onbPointRecord;

  /// No description provided for @onbPointTrack.
  ///
  /// In en, this message translates to:
  /// **'See balances, net worth and where your money goes'**
  String get onbPointTrack;

  /// No description provided for @onbPointPlan.
  ///
  /// In en, this message translates to:
  /// **'Budgets, recurring bills and savings goals'**
  String get onbPointPlan;

  /// No description provided for @onbPointProject.
  ///
  /// In en, this message translates to:
  /// **'Forecast your balance months ahead'**
  String get onbPointProject;

  /// No description provided for @onbPointPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private: encrypted on this device, no telemetry'**
  String get onbPointPrivate;

  /// No description provided for @onbFormatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Language & formats'**
  String get onbFormatsTitle;

  /// No description provided for @onbFormatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change all of this later in Settings.'**
  String get onbFormatsSubtitle;

  /// No description provided for @onbPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get onbPreview;

  /// No description provided for @onbPeriodTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget period'**
  String get onbPeriodTitle;

  /// No description provided for @onbPeriodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When does your money month start? Many people use the day their salary arrives.'**
  String get onbPeriodSubtitle;

  /// No description provided for @onbLastDayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Last day of the month'**
  String get onbLastDayOfMonth;

  /// No description provided for @onbSalaryHint.
  ///
  /// In en, this message translates to:
  /// **'Tip: after you add your salary as a recurring income you can let periods start on payday (Settings › Budgets).'**
  String get onbSalaryHint;

  /// No description provided for @onbStartTitle.
  ///
  /// In en, this message translates to:
  /// **'How do you want to start?'**
  String get onbStartTitle;

  /// No description provided for @onbStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default categories are created either way.'**
  String get onbStartSubtitle;

  /// No description provided for @onbImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from Excel or CSV'**
  String get onbImportTitle;

  /// No description provided for @onbImportText.
  ///
  /// In en, this message translates to:
  /// **'Bring your existing sheet with all its history. The importer maps columns, categories and accounts.'**
  String get onbImportText;

  /// No description provided for @onbFreshTitle.
  ///
  /// In en, this message translates to:
  /// **'Start fresh'**
  String get onbFreshTitle;

  /// No description provided for @onbFreshText.
  ///
  /// In en, this message translates to:
  /// **'Add your accounts with their current balances.'**
  String get onbFreshText;

  /// No description provided for @onbAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your accounts'**
  String get onbAccountsTitle;

  /// No description provided for @onbAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter today\'s balance for each account. You can add more later.'**
  String get onbAccountsSubtitle;

  /// No description provided for @onbAccountName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get onbAccountName;

  /// No description provided for @onbAccountType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get onbAccountType;

  /// No description provided for @onbOpeningBalance.
  ///
  /// In en, this message translates to:
  /// **'Current balance'**
  String get onbOpeningBalance;

  /// No description provided for @onbAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add another account'**
  String get onbAddAccount;

  /// No description provided for @onbLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect your data'**
  String get onbLockTitle;

  /// No description provided for @onbLockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lock the app with a PIN, password or biometrics.'**
  String get onbLockSubtitle;

  /// No description provided for @onbTypeChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get onbTypeChecking;

  /// No description provided for @onbTypeSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get onbTypeSavings;

  /// No description provided for @onbTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get onbTypeCash;

  /// No description provided for @onbTypeCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get onbTypeCreditCard;

  /// No description provided for @onbTypeInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get onbTypeInvestment;

  /// No description provided for @onbTypeLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get onbTypeLoan;

  /// No description provided for @onbTypeOtherAsset.
  ///
  /// In en, this message translates to:
  /// **'Other asset'**
  String get onbTypeOtherAsset;

  /// No description provided for @onbTypeOtherLiability.
  ///
  /// In en, this message translates to:
  /// **'Other liability'**
  String get onbTypeOtherLiability;

  /// No description provided for @planTabBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get planTabBudgets;

  /// No description provided for @planTabRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get planTabRecurring;

  /// No description provided for @planTabGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get planTabGoals;

  /// No description provided for @planBillsCalendar.
  ///
  /// In en, this message translates to:
  /// **'Bills calendar'**
  String get planBillsCalendar;

  /// No description provided for @planPreviousPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get planPreviousPeriod;

  /// No description provided for @planNextPeriod.
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get planNextPeriod;

  /// No description provided for @planToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get planToday;

  /// No description provided for @planPeriodSemantics.
  ///
  /// In en, this message translates to:
  /// **'Period {title}, {range}'**
  String planPeriodSemantics(String title, String range);

  /// No description provided for @recurringNew.
  ///
  /// In en, this message translates to:
  /// **'New recurring item'**
  String get recurringNew;

  /// No description provided for @recurringEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit recurring item'**
  String get recurringEdit;

  /// No description provided for @recurringEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recurring items yet. Add rent, salary or subscriptions to see them coming.'**
  String get recurringEmpty;

  /// No description provided for @recurringSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select a recurring item to edit it.'**
  String get recurringSelectHint;

  /// No description provided for @recurringNext30Days.
  ///
  /// In en, this message translates to:
  /// **'Next 30 days'**
  String get recurringNext30Days;

  /// No description provided for @recurringBills.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No bills} =1{1 bill} other{{count} bills}}'**
  String recurringBills(int count);

  /// No description provided for @recurringIncomeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No income} =1{1 income} other{{count} incomes}}'**
  String recurringIncomeCount(int count);

  /// No description provided for @recurringDueTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation'**
  String get recurringDueTitle;

  /// No description provided for @recurringDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get recurringDueToday;

  /// No description provided for @recurringOverdueDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Overdue by 1 day} other{Overdue by {days} days}}'**
  String recurringOverdueDays(int days);

  /// No description provided for @recurringDueInDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Tomorrow} other{In {days} days}}'**
  String recurringDueInDays(int days);

  /// No description provided for @recurringMorePending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{+1 more due} other{+{count} more due}}'**
  String recurringMorePending(int count);

  /// No description provided for @recurringSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get recurringSkip;

  /// No description provided for @recurringEditConfirm.
  ///
  /// In en, this message translates to:
  /// **'Edit & confirm'**
  String get recurringEditConfirm;

  /// No description provided for @recurringConfirmed.
  ///
  /// In en, this message translates to:
  /// **'“{name}” posted'**
  String recurringConfirmed(String name);

  /// No description provided for @recurringSkipped.
  ///
  /// In en, this message translates to:
  /// **'“{name}” skipped'**
  String recurringSkipped(String name);

  /// No description provided for @recurringActiveRules.
  ///
  /// In en, this message translates to:
  /// **'Active ({count})'**
  String recurringActiveRules(int count);

  /// No description provided for @recurringInactiveRules.
  ///
  /// In en, this message translates to:
  /// **'Paused or ended'**
  String get recurringInactiveRules;

  /// No description provided for @recurringNoActive.
  ///
  /// In en, this message translates to:
  /// **'No active recurring items.'**
  String get recurringNoActive;

  /// No description provided for @recurringPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get recurringPaused;

  /// No description provided for @recurringEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get recurringEnded;

  /// No description provided for @recurringNextOn.
  ///
  /// In en, this message translates to:
  /// **'Next {date}'**
  String recurringNextOn(String date);

  /// No description provided for @recurringAutoPostShort.
  ///
  /// In en, this message translates to:
  /// **'auto-post'**
  String get recurringAutoPostShort;

  /// No description provided for @recurringConfirmShort.
  ///
  /// In en, this message translates to:
  /// **'confirm'**
  String get recurringConfirmShort;

  /// No description provided for @recurringPostedLabel.
  ///
  /// In en, this message translates to:
  /// **'posted'**
  String get recurringPostedLabel;

  /// No description provided for @recurringWhat.
  ///
  /// In en, this message translates to:
  /// **'What'**
  String get recurringWhat;

  /// No description provided for @recurringWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get recurringWhen;

  /// No description provided for @recurringPosting.
  ///
  /// In en, this message translates to:
  /// **'Posting & reminders'**
  String get recurringPosting;

  /// No description provided for @recurringName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get recurringName;

  /// No description provided for @recurringFromAccount.
  ///
  /// In en, this message translates to:
  /// **'From account'**
  String get recurringFromAccount;

  /// No description provided for @recurringToAccount.
  ///
  /// In en, this message translates to:
  /// **'To account'**
  String get recurringToAccount;

  /// No description provided for @recurringNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get recurringNotSet;

  /// No description provided for @recurringSplit.
  ///
  /// In en, this message translates to:
  /// **'Split across categories'**
  String get recurringSplit;

  /// No description provided for @recurringAddSplit.
  ///
  /// In en, this message translates to:
  /// **'Add line'**
  String get recurringAddSplit;

  /// No description provided for @recurringSplitBalanced.
  ///
  /// In en, this message translates to:
  /// **'Split adds up'**
  String get recurringSplitBalanced;

  /// No description provided for @recurringSplitRemainder.
  ///
  /// In en, this message translates to:
  /// **'{amount} not assigned'**
  String recurringSplitRemainder(String amount);

  /// No description provided for @recurringTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get recurringTags;

  /// No description provided for @recurringRepeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get recurringRepeats;

  /// No description provided for @recurringPresetMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly on a day'**
  String get recurringPresetMonthly;

  /// No description provided for @recurringPresetLastDay.
  ///
  /// In en, this message translates to:
  /// **'Last day of the month'**
  String get recurringPresetLastDay;

  /// No description provided for @recurringPresetLastBusinessDay.
  ///
  /// In en, this message translates to:
  /// **'Last business day of the month'**
  String get recurringPresetLastBusinessDay;

  /// No description provided for @recurringPresetWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurringPresetWeekly;

  /// No description provided for @recurringPresetQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get recurringPresetQuarterly;

  /// No description provided for @recurringPresetYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get recurringPresetYearly;

  /// No description provided for @recurringPresetDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurringPresetDaily;

  /// No description provided for @recurringPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom (RRULE)'**
  String get recurringPresetCustom;

  /// No description provided for @recurringDayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Day of the month'**
  String get recurringDayOfMonth;

  /// No description provided for @recurringMonthEndHint.
  ///
  /// In en, this message translates to:
  /// **'In shorter months the last day is used.'**
  String get recurringMonthEndHint;

  /// No description provided for @recurringEveryNMonths.
  ///
  /// In en, this message translates to:
  /// **'Every … months'**
  String get recurringEveryNMonths;

  /// No description provided for @recurringEveryNWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every … weeks'**
  String get recurringEveryNWeeks;

  /// No description provided for @recurringEveryNYears.
  ///
  /// In en, this message translates to:
  /// **'Every … years'**
  String get recurringEveryNYears;

  /// No description provided for @recurringEveryNDays.
  ///
  /// In en, this message translates to:
  /// **'Every … days'**
  String get recurringEveryNDays;

  /// No description provided for @recurringMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get recurringMonth;

  /// No description provided for @recurringDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get recurringDay;

  /// No description provided for @recurringRRule.
  ///
  /// In en, this message translates to:
  /// **'Recurrence rule (RRULE)'**
  String get recurringRRule;

  /// No description provided for @recurringRRuleHelp.
  ///
  /// In en, this message translates to:
  /// **'RFC 5545, e.g. FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=15'**
  String get recurringRRuleHelp;

  /// No description provided for @recurringRRuleInvalid.
  ///
  /// In en, this message translates to:
  /// **'This schedule is not valid.'**
  String get recurringRRuleInvalid;

  /// No description provided for @recurringDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get recurringDecrease;

  /// No description provided for @recurringIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get recurringIncrease;

  /// No description provided for @recurringStartDate.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get recurringStartDate;

  /// No description provided for @recurringEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get recurringEnds;

  /// No description provided for @recurringEndsNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get recurringEndsNever;

  /// No description provided for @recurringEndsOnDate.
  ///
  /// In en, this message translates to:
  /// **'On date'**
  String get recurringEndsOnDate;

  /// No description provided for @recurringEndsAfterCount.
  ///
  /// In en, this message translates to:
  /// **'After …'**
  String get recurringEndsAfterCount;

  /// No description provided for @recurringEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get recurringEndDate;

  /// No description provided for @recurringOccurrences.
  ///
  /// In en, this message translates to:
  /// **'Number of occurrences'**
  String get recurringOccurrences;

  /// No description provided for @recurringShift.
  ///
  /// In en, this message translates to:
  /// **'On weekends and holidays'**
  String get recurringShift;

  /// No description provided for @recurringShiftNone.
  ///
  /// In en, this message translates to:
  /// **'Keep date'**
  String get recurringShiftNone;

  /// No description provided for @recurringShiftEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get recurringShiftEarlier;

  /// No description provided for @recurringShiftLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get recurringShiftLater;

  /// No description provided for @recurringAutoPostHelp.
  ///
  /// In en, this message translates to:
  /// **'Posted automatically on the due date when the app starts.'**
  String get recurringAutoPostHelp;

  /// No description provided for @recurringRemindHelp.
  ///
  /// In en, this message translates to:
  /// **'You confirm (or skip) each occurrence; it is not posted on its own.'**
  String get recurringRemindHelp;

  /// No description provided for @recurringRemindDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Remind on the due date} =1{Remind 1 day before} other{Remind {days} days before}}'**
  String recurringRemindDaysBefore(int days);

  /// No description provided for @recurringNotifyTime.
  ///
  /// In en, this message translates to:
  /// **'Notification time'**
  String get recurringNotifyTime;

  /// No description provided for @recurringActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get recurringActive;

  /// No description provided for @recurringActiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Paused items are not posted and not reminded.'**
  String get recurringActiveHelp;

  /// No description provided for @recurringAmountChanges.
  ///
  /// In en, this message translates to:
  /// **'Amount changes'**
  String get recurringAmountChanges;

  /// No description provided for @recurringAmountChangesHelp.
  ///
  /// In en, this message translates to:
  /// **'A new amount from a date (e.g. a rent increase). Earlier postings stay unchanged.'**
  String get recurringAmountChangesHelp;

  /// No description provided for @recurringAddAmountChange.
  ///
  /// In en, this message translates to:
  /// **'Add amount change'**
  String get recurringAddAmountChange;

  /// No description provided for @recurringFromDate.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String recurringFromDate(String date);

  /// No description provided for @recurringEffectiveFrom.
  ///
  /// In en, this message translates to:
  /// **'Effective from'**
  String get recurringEffectiveFrom;

  /// No description provided for @recurringNewAmount.
  ///
  /// In en, this message translates to:
  /// **'New amount'**
  String get recurringNewAmount;

  /// No description provided for @recurringNextOccurrences.
  ///
  /// In en, this message translates to:
  /// **'Next occurrences'**
  String get recurringNextOccurrences;

  /// No description provided for @recurringNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming occurrences.'**
  String get recurringNoUpcoming;

  /// No description provided for @recurringShiftedFrom.
  ///
  /// In en, this message translates to:
  /// **'{date} (moved from {original})'**
  String recurringShiftedFrom(String date, String original);

  /// No description provided for @recurringLastPosted.
  ///
  /// In en, this message translates to:
  /// **'Handled up to {date}'**
  String recurringLastPosted(String date);

  /// No description provided for @recurringPostedHistory.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get recurringPostedHistory;

  /// No description provided for @recurringNothingPosted.
  ///
  /// In en, this message translates to:
  /// **'Nothing posted yet.'**
  String get recurringNothingPosted;

  /// No description provided for @recurringSaved.
  ///
  /// In en, this message translates to:
  /// **'Recurring item saved'**
  String get recurringSaved;

  /// No description provided for @recurringDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Already posted transactions are kept.'**
  String get recurringDeleteMessage;

  /// No description provided for @recurringNotFound.
  ///
  /// In en, this message translates to:
  /// **'This recurring item no longer exists.'**
  String get recurringNotFound;

  /// No description provided for @recurringErrorName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get recurringErrorName;

  /// No description provided for @recurringErrorAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get recurringErrorAmount;

  /// No description provided for @recurringErrorEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end date must not be before the start date'**
  String get recurringErrorEndBeforeStart;

  /// No description provided for @recurringErrorCount.
  ///
  /// In en, this message translates to:
  /// **'Enter at least 1'**
  String get recurringErrorCount;

  /// No description provided for @recurringErrorAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose an account'**
  String get recurringErrorAccount;

  /// No description provided for @recurringErrorTransferAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose the target account'**
  String get recurringErrorTransferAccount;

  /// No description provided for @recurringErrorSameAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose two different accounts'**
  String get recurringErrorSameAccount;

  /// No description provided for @recurringErrorSplits.
  ///
  /// In en, this message translates to:
  /// **'The split lines must add up to the amount'**
  String get recurringErrorSplits;

  /// No description provided for @recurringPickRule.
  ///
  /// In en, this message translates to:
  /// **'Choose a recurring item'**
  String get recurringPickRule;

  /// No description provided for @recurringPickIncome.
  ///
  /// In en, this message translates to:
  /// **'Choose the salary'**
  String get recurringPickIncome;

  /// No description provided for @recurringNoIncomeRules.
  ///
  /// In en, this message translates to:
  /// **'No recurring income yet. Add your salary as recurring income first.'**
  String get recurringNoIncomeRules;

  /// No description provided for @recurringNothingOnDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing due on this day.'**
  String get recurringNothingOnDay;

  /// No description provided for @recurringMonthOut.
  ///
  /// In en, this message translates to:
  /// **'Bills this month'**
  String get recurringMonthOut;

  /// No description provided for @recurringMonthIn.
  ///
  /// In en, this message translates to:
  /// **'Income this month'**
  String get recurringMonthIn;

  /// No description provided for @recurringReminderBillBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} due on {date}'**
  String recurringReminderBillBody(String amount, String date);

  /// No description provided for @recurringReminderIncomeBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} expected on {date}'**
  String recurringReminderIncomeBody(String amount, String date);

  /// No description provided for @recurringChannelBills.
  ///
  /// In en, this message translates to:
  /// **'Bill reminders'**
  String get recurringChannelBills;

  /// No description provided for @recurringChannelIncome.
  ///
  /// In en, this message translates to:
  /// **'Income reminders'**
  String get recurringChannelIncome;

  /// No description provided for @recurringChannelLowBalance.
  ///
  /// In en, this message translates to:
  /// **'Low balance'**
  String get recurringChannelLowBalance;

  /// No description provided for @recurringChannelBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budget alerts'**
  String get recurringChannelBudgets;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsSpendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get reportsSpendingTitle;

  /// No description provided for @reportsIncomeByCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Income by category'**
  String get reportsIncomeByCategoryTitle;

  /// No description provided for @reportsIncomeExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Income vs expenses'**
  String get reportsIncomeExpenseTitle;

  /// No description provided for @reportsNetWorthTitle.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get reportsNetWorthTitle;

  /// No description provided for @reportsCategoryTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'Category trend'**
  String get reportsCategoryTrendTitle;

  /// No description provided for @reportsTopPayeesTitle.
  ///
  /// In en, this message translates to:
  /// **'Top payees'**
  String get reportsTopPayeesTitle;

  /// No description provided for @reportsComparisonTitle.
  ///
  /// In en, this message translates to:
  /// **'Period comparison'**
  String get reportsComparisonTitle;

  /// No description provided for @reportsPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get reportsPeriod;

  /// No description provided for @reportsCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range…'**
  String get reportsCustomRange;

  /// No description provided for @reportsPreviousPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get reportsPreviousPeriod;

  /// No description provided for @reportsNextPeriod.
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get reportsNextPeriod;

  /// No description provided for @reportsAllAccounts.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get reportsAllAccounts;

  /// No description provided for @reportsAccountsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 account} other{{count} accounts}}'**
  String reportsAccountsCount(int count);

  /// No description provided for @reportsAllTags.
  ///
  /// In en, this message translates to:
  /// **'All tags'**
  String get reportsAllTags;

  /// No description provided for @reportsTagsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tag} other{{count} tags}}'**
  String reportsTagsCount(int count);

  /// No description provided for @reportsCustomField.
  ///
  /// In en, this message translates to:
  /// **'Custom field'**
  String get reportsCustomField;

  /// No description provided for @reportsCustomFieldValue.
  ///
  /// In en, this message translates to:
  /// **'{field}: {value}'**
  String reportsCustomFieldValue(String field, String value);

  /// No description provided for @reportsChooseField.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get reportsChooseField;

  /// No description provided for @reportsFieldValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get reportsFieldValue;

  /// No description provided for @reportsNoFields.
  ///
  /// In en, this message translates to:
  /// **'No custom fields yet'**
  String get reportsNoFields;

  /// No description provided for @reportsIncludeExcluded.
  ///
  /// In en, this message translates to:
  /// **'Include excluded'**
  String get reportsIncludeExcluded;

  /// No description provided for @reportsIncludeExcludedHint.
  ///
  /// In en, this message translates to:
  /// **'Includes the categories, accounts and tags excluded in Settings › Reports'**
  String get reportsIncludeExcludedHint;

  /// No description provided for @reportsClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get reportsClearFilters;

  /// No description provided for @reportsExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get reportsExportCsv;

  /// No description provided for @reportsExported.
  ///
  /// In en, this message translates to:
  /// **'Report exported'**
  String get reportsExported;

  /// No description provided for @reportsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {message}'**
  String reportsExportFailed(String message);

  /// No description provided for @reportsNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get reportsNoData;

  /// No description provided for @reportsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get reportsTotal;

  /// No description provided for @reportsUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorised'**
  String get reportsUncategorized;

  /// No description provided for @reportsOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportsOther;

  /// No description provided for @reportsArchived.
  ///
  /// In en, this message translates to:
  /// **'archived'**
  String get reportsArchived;

  /// No description provided for @reportsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get reportsData;

  /// No description provided for @reportsColShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get reportsColShare;

  /// No description provided for @reportsColCount.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get reportsColCount;

  /// No description provided for @reportsColPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get reportsColPeriod;

  /// No description provided for @reportsColIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get reportsColIncome;

  /// No description provided for @reportsColExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get reportsColExpenses;

  /// No description provided for @reportsColNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get reportsColNet;

  /// No description provided for @reportsColSavingsRate.
  ///
  /// In en, this message translates to:
  /// **'Savings rate'**
  String get reportsColSavingsRate;

  /// No description provided for @reportsColMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get reportsColMonth;

  /// No description provided for @reportsColAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get reportsColAssets;

  /// No description provided for @reportsColLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get reportsColLiabilities;

  /// No description provided for @reportsColNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get reportsColNetWorth;

  /// No description provided for @reportsColAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get reportsColAverage;

  /// No description provided for @reportsColCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get reportsColCurrent;

  /// No description provided for @reportsColPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get reportsColPrevious;

  /// No description provided for @reportsColLastYear.
  ///
  /// In en, this message translates to:
  /// **'Last year'**
  String get reportsColLastYear;

  /// No description provided for @reportsColDeltaPrevious.
  ///
  /// In en, this message translates to:
  /// **'Δ previous'**
  String get reportsColDeltaPrevious;

  /// No description provided for @reportsColDeltaPreviousPct.
  ///
  /// In en, this message translates to:
  /// **'Δ previous %'**
  String get reportsColDeltaPreviousPct;

  /// No description provided for @reportsColDeltaLastYear.
  ///
  /// In en, this message translates to:
  /// **'Δ last year'**
  String get reportsColDeltaLastYear;

  /// No description provided for @reportsColDeltaLastYearPct.
  ///
  /// In en, this message translates to:
  /// **'Δ last year %'**
  String get reportsColDeltaLastYearPct;

  /// No description provided for @reportsIntervalMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get reportsIntervalMonth;

  /// No description provided for @reportsIntervalQuarter.
  ///
  /// In en, this message translates to:
  /// **'Quarter'**
  String get reportsIntervalQuarter;

  /// No description provided for @reportsIntervalYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get reportsIntervalYear;

  /// No description provided for @reportsIntervalBudgetPeriod.
  ///
  /// In en, this message translates to:
  /// **'Budget period'**
  String get reportsIntervalBudgetPeriod;

  /// No description provided for @reportsSortTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get reportsSortTotal;

  /// No description provided for @reportsSortCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get reportsSortCount;

  /// No description provided for @reportsSortAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get reportsSortAverage;

  /// No description provided for @reportsAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get reportsAllCategories;

  /// No description provided for @reportsShowTransactions.
  ///
  /// In en, this message translates to:
  /// **'Show transactions'**
  String get reportsShowTransactions;

  /// No description provided for @reportsSubcategories.
  ///
  /// In en, this message translates to:
  /// **'Show subcategories'**
  String get reportsSubcategories;

  /// No description provided for @reportsChooseCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get reportsChooseCategories;

  /// No description provided for @reportsTopCategoriesAuto.
  ///
  /// In en, this message translates to:
  /// **'Top 3 categories'**
  String get reportsTopCategoriesAuto;

  /// No description provided for @reportsSavingsRate.
  ///
  /// In en, this message translates to:
  /// **'Savings rate'**
  String get reportsSavingsRate;

  /// No description provided for @reportsNetChange.
  ///
  /// In en, this message translates to:
  /// **'Net change'**
  String get reportsNetChange;

  /// No description provided for @reportsChangeInPeriod.
  ///
  /// In en, this message translates to:
  /// **'{amount} in this period'**
  String reportsChangeInPeriod(String amount);

  /// No description provided for @reportsVsPrevious.
  ///
  /// In en, this message translates to:
  /// **'vs previous period'**
  String get reportsVsPrevious;

  /// No description provided for @reportsVsLastYear.
  ///
  /// In en, this message translates to:
  /// **'vs same period last year'**
  String get reportsVsLastYear;

  /// No description provided for @reportsQuarterLabel.
  ///
  /// In en, this message translates to:
  /// **'Q{quarter} {year}'**
  String reportsQuarterLabel(int quarter, String year);

  /// No description provided for @reportsDonutSummary.
  ///
  /// In en, this message translates to:
  /// **'{title}, total {total}. {items}'**
  String reportsDonutSummary(String title, String total, String items);

  /// No description provided for @reportsBarsSummary.
  ///
  /// In en, this message translates to:
  /// **'Income vs expenses over {count} periods: income {income}, expenses {expenses}.'**
  String reportsBarsSummary(int count, String income, String expenses);

  /// No description provided for @reportsLineSummary.
  ///
  /// In en, this message translates to:
  /// **'Net worth from {from} to {to}: {start} to {end}.'**
  String reportsLineSummary(String from, String to, String start, String end);

  /// No description provided for @reportsTrendSummary.
  ///
  /// In en, this message translates to:
  /// **'Category trend over {count} periods. {items}'**
  String reportsTrendSummary(int count, String items);

  /// No description provided for @reportsPayeesSummary.
  ///
  /// In en, this message translates to:
  /// **'Top payees: {items}'**
  String reportsPayeesSummary(String items);

  /// No description provided for @reportsComparisonSummary.
  ///
  /// In en, this message translates to:
  /// **'Total {current}, previous period {previous}, last year {lastYear}.'**
  String reportsComparisonSummary(
    String current,
    String previous,
    String lastYear,
  );

  /// No description provided for @reportsOpenReport.
  ///
  /// In en, this message translates to:
  /// **'Open report'**
  String get reportsOpenReport;

  /// No description provided for @reportsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Report not found'**
  String get reportsNotFound;

  /// No description provided for @rulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get rulesTitle;

  /// No description provided for @rulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No rules yet. Rules fill in category, tags and more when a payee, note or amount matches.'**
  String get rulesEmpty;

  /// No description provided for @rulesAdd.
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get rulesAdd;

  /// No description provided for @rulesOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Rules run from top to bottom. For each field the first matching rule wins; drag to change the order.'**
  String get rulesOrderHint;

  /// No description provided for @rulesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get rulesDisabled;

  /// No description provided for @rulesEnable.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get rulesEnable;

  /// No description provided for @rulesRerun.
  ///
  /// In en, this message translates to:
  /// **'Re-run rules'**
  String get rulesRerun;

  /// No description provided for @rulesRerunTitle.
  ///
  /// In en, this message translates to:
  /// **'Re-run rules on existing transactions'**
  String get rulesRerunTitle;

  /// No description provided for @rulesRerunOnlyUncategorised.
  ///
  /// In en, this message translates to:
  /// **'Only transactions without a category'**
  String get rulesRerunOnlyUncategorised;

  /// No description provided for @rulesRerunAllHint.
  ///
  /// In en, this message translates to:
  /// **'Rules re-evaluate every transaction and replace existing categories, notes and status.'**
  String get rulesRerunAllHint;

  /// No description provided for @rulesRerunPreview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No transaction would change} =1{1 transaction would change} other{{count} transactions would change}} ({scanned} checked)'**
  String rulesRerunPreview(int count, int scanned);

  /// No description provided for @rulesRerunApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get rulesRerunApply;

  /// No description provided for @rulesRerunDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing changed} =1{1 transaction updated} other{{count} transactions updated}}'**
  String rulesRerunDone(int count);

  /// No description provided for @rulesNoRules.
  ///
  /// In en, this message translates to:
  /// **'There are no enabled rules.'**
  String get rulesNoRules;

  /// No description provided for @rulesNew.
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get rulesNew;

  /// No description provided for @rulesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit rule'**
  String get rulesEdit;

  /// No description provided for @rulesName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get rulesName;

  /// No description provided for @rulesConditions.
  ///
  /// In en, this message translates to:
  /// **'If'**
  String get rulesConditions;

  /// No description provided for @rulesMatchAll.
  ///
  /// In en, this message translates to:
  /// **'All match'**
  String get rulesMatchAll;

  /// No description provided for @rulesMatchAny.
  ///
  /// In en, this message translates to:
  /// **'Any matches'**
  String get rulesMatchAny;

  /// No description provided for @rulesAddCondition.
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get rulesAddCondition;

  /// No description provided for @rulesCondText.
  ///
  /// In en, this message translates to:
  /// **'Payee / note text'**
  String get rulesCondText;

  /// No description provided for @rulesCondAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount range'**
  String get rulesCondAmount;

  /// No description provided for @rulesCondAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get rulesCondAccount;

  /// No description provided for @rulesCondType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get rulesCondType;

  /// No description provided for @rulesFieldPayee.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get rulesFieldPayee;

  /// No description provided for @rulesFieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get rulesFieldNote;

  /// No description provided for @rulesFieldPayeeOrNote.
  ///
  /// In en, this message translates to:
  /// **'Payee or note'**
  String get rulesFieldPayeeOrNote;

  /// No description provided for @rulesOpContains.
  ///
  /// In en, this message translates to:
  /// **'contains'**
  String get rulesOpContains;

  /// No description provided for @rulesOpEquals.
  ///
  /// In en, this message translates to:
  /// **'is'**
  String get rulesOpEquals;

  /// No description provided for @rulesOpStartsWith.
  ///
  /// In en, this message translates to:
  /// **'starts with'**
  String get rulesOpStartsWith;

  /// No description provided for @rulesOpEndsWith.
  ///
  /// In en, this message translates to:
  /// **'ends with'**
  String get rulesOpEndsWith;

  /// No description provided for @rulesOpRegex.
  ///
  /// In en, this message translates to:
  /// **'matches regex'**
  String get rulesOpRegex;

  /// No description provided for @rulesNegate.
  ///
  /// In en, this message translates to:
  /// **'Negate (does not match)'**
  String get rulesNegate;

  /// No description provided for @rulesText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get rulesText;

  /// No description provided for @rulesInvalidRegex.
  ///
  /// In en, this message translates to:
  /// **'Invalid regular expression'**
  String get rulesInvalidRegex;

  /// No description provided for @rulesAmountMin.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get rulesAmountMin;

  /// No description provided for @rulesAmountMax.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get rulesAmountMax;

  /// No description provided for @rulesAmountAbs.
  ///
  /// In en, this message translates to:
  /// **'Ignore the sign'**
  String get rulesAmountAbs;

  /// No description provided for @rulesChooseAccounts.
  ///
  /// In en, this message translates to:
  /// **'Choose accounts'**
  String get rulesChooseAccounts;

  /// No description provided for @rulesAccountsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No account} =1{1 account} other{{count} accounts}}'**
  String rulesAccountsSelected(int count);

  /// No description provided for @rulesRemoveCondition.
  ///
  /// In en, this message translates to:
  /// **'Remove condition'**
  String get rulesRemoveCondition;

  /// No description provided for @rulesActions.
  ///
  /// In en, this message translates to:
  /// **'Then'**
  String get rulesActions;

  /// No description provided for @rulesActCategory.
  ///
  /// In en, this message translates to:
  /// **'Set category'**
  String get rulesActCategory;

  /// No description provided for @rulesActTags.
  ///
  /// In en, this message translates to:
  /// **'Add tags'**
  String get rulesActTags;

  /// No description provided for @rulesActPayee.
  ///
  /// In en, this message translates to:
  /// **'Rename payee to'**
  String get rulesActPayee;

  /// No description provided for @rulesActNote.
  ///
  /// In en, this message translates to:
  /// **'Set note'**
  String get rulesActNote;

  /// No description provided for @rulesActStatus.
  ///
  /// In en, this message translates to:
  /// **'Set status'**
  String get rulesActStatus;

  /// No description provided for @rulesActCustomFields.
  ///
  /// In en, this message translates to:
  /// **'Set custom fields'**
  String get rulesActCustomFields;

  /// No description provided for @rulesKeep.
  ///
  /// In en, this message translates to:
  /// **'Don\'t change'**
  String get rulesKeep;

  /// No description provided for @rulesOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Replace existing values'**
  String get rulesOverwrite;

  /// No description provided for @rulesOverwriteHint.
  ///
  /// In en, this message translates to:
  /// **'Otherwise the rule only fills empty fields. A payee rename always applies.'**
  String get rulesOverwriteHint;

  /// No description provided for @rulesApplyOnEntry.
  ///
  /// In en, this message translates to:
  /// **'Apply when entering transactions'**
  String get rulesApplyOnEntry;

  /// No description provided for @rulesApplyOnImport.
  ///
  /// In en, this message translates to:
  /// **'Apply when importing'**
  String get rulesApplyOnImport;

  /// No description provided for @rulesTest.
  ///
  /// In en, this message translates to:
  /// **'Try it'**
  String get rulesTest;

  /// No description provided for @rulesTestHint.
  ///
  /// In en, this message translates to:
  /// **'Enter an example to see what the rule does.'**
  String get rulesTestHint;

  /// No description provided for @rulesTestAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (negative = expense)'**
  String get rulesTestAmount;

  /// No description provided for @rulesTestMatch.
  ///
  /// In en, this message translates to:
  /// **'Matches – would set:'**
  String get rulesTestMatch;

  /// No description provided for @rulesTestNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Doesn\'t match'**
  String get rulesTestNoMatch;

  /// No description provided for @rulesTestNoChange.
  ///
  /// In en, this message translates to:
  /// **'Matches, but the fields are already set'**
  String get rulesTestNoChange;

  /// No description provided for @rulesSaved.
  ///
  /// In en, this message translates to:
  /// **'Rule saved'**
  String get rulesSaved;

  /// No description provided for @rulesDeleted.
  ///
  /// In en, this message translates to:
  /// **'Rule deleted'**
  String get rulesDeleted;

  /// No description provided for @rulesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Give the rule a name, at least one complete condition and one action.'**
  String get rulesInvalid;

  /// No description provided for @rulesCreateFromTxn.
  ///
  /// In en, this message translates to:
  /// **'Create rule from this transaction'**
  String get rulesCreateFromTxn;

  /// No description provided for @rulesSummaryWhen.
  ///
  /// In en, this message translates to:
  /// **'When {condition}'**
  String rulesSummaryWhen(String condition);

  /// No description provided for @rulesSummaryAmount.
  ///
  /// In en, this message translates to:
  /// **'amount {range}'**
  String rulesSummaryAmount(String range);

  /// No description provided for @rulesSummaryAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get rulesSummaryAnd;

  /// No description provided for @rulesSummaryOr.
  ///
  /// In en, this message translates to:
  /// **' or '**
  String get rulesSummaryOr;

  /// No description provided for @rulesSummaryNoConditions.
  ///
  /// In en, this message translates to:
  /// **'No conditions'**
  String get rulesSummaryNoConditions;

  /// No description provided for @rulesYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get rulesYes;

  /// No description provided for @rulesNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get rulesNo;

  /// No description provided for @scenariosTitle.
  ///
  /// In en, this message translates to:
  /// **'Scenarios'**
  String get scenariosTitle;

  /// No description provided for @scenariosNew.
  ///
  /// In en, this message translates to:
  /// **'New scenario'**
  String get scenariosNew;

  /// No description provided for @scenariosEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit scenario'**
  String get scenariosEdit;

  /// No description provided for @scenariosEmpty.
  ///
  /// In en, this message translates to:
  /// **'No scenarios yet. A scenario changes the plan – a raise, a big purchase, ending a loan – without touching your data.'**
  String get scenariosEmpty;

  /// No description provided for @scenariosName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get scenariosName;

  /// No description provided for @scenariosNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get scenariosNameRequired;

  /// No description provided for @scenariosColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get scenariosColor;

  /// No description provided for @scenariosColorAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get scenariosColorAuto;

  /// No description provided for @scenariosColorOption.
  ///
  /// In en, this message translates to:
  /// **'Colour {index}'**
  String scenariosColorOption(int index);

  /// No description provided for @scenariosCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare on the forecast'**
  String get scenariosCompare;

  /// No description provided for @scenariosCompareDesc.
  ///
  /// In en, this message translates to:
  /// **'Up to 5 scenarios are shown next to the baseline.'**
  String get scenariosCompareDesc;

  /// No description provided for @scenariosMaxCompared.
  ///
  /// In en, this message translates to:
  /// **'Up to 5 scenarios can be compared. Turn one off first.'**
  String get scenariosMaxCompared;

  /// No description provided for @scenariosChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get scenariosChanges;

  /// No description provided for @scenariosAddChange.
  ///
  /// In en, this message translates to:
  /// **'Add change'**
  String get scenariosAddChange;

  /// No description provided for @scenariosNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes yet. Add one to see its effect.'**
  String get scenariosNoChanges;

  /// No description provided for @scenariosDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get scenariosDuplicate;

  /// No description provided for @scenariosCopyName.
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String scenariosCopyName(Object name);

  /// No description provided for @scenariosDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete scenario?'**
  String get scenariosDeleteTitle;

  /// No description provided for @scenariosDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'“{name}” will be deleted. Your data is not affected.'**
  String scenariosDeleteMessage(Object name);

  /// No description provided for @scenariosNotFound.
  ///
  /// In en, this message translates to:
  /// **'This scenario no longer exists.'**
  String get scenariosNotFound;

  /// No description provided for @scenariosModuleOff.
  ///
  /// In en, this message translates to:
  /// **'Scenarios are turned off. You can turn them on in Settings › Navigation & modules.'**
  String get scenariosModuleOff;

  /// No description provided for @scenariosSaved.
  ///
  /// In en, this message translates to:
  /// **'Scenario saved'**
  String get scenariosSaved;

  /// No description provided for @scenariosChangeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No changes} =1{1 change} other{{count} changes}}'**
  String scenariosChangeCount(int count);

  /// No description provided for @scenariosTypeOneOff.
  ///
  /// In en, this message translates to:
  /// **'One-off event'**
  String get scenariosTypeOneOff;

  /// No description provided for @scenariosTypeCategory.
  ///
  /// In en, this message translates to:
  /// **'Change spending in a category'**
  String get scenariosTypeCategory;

  /// No description provided for @scenariosTypeRecurringChange.
  ///
  /// In en, this message translates to:
  /// **'Change a recurring item'**
  String get scenariosTypeRecurringChange;

  /// No description provided for @scenariosTypeAddRecurring.
  ///
  /// In en, this message translates to:
  /// **'Add a recurring item'**
  String get scenariosTypeAddRecurring;

  /// No description provided for @scenariosTypeEndRecurring.
  ///
  /// In en, this message translates to:
  /// **'End a recurring item'**
  String get scenariosTypeEndRecurring;

  /// No description provided for @scenariosTypeReturn.
  ///
  /// In en, this message translates to:
  /// **'Different return'**
  String get scenariosTypeReturn;

  /// No description provided for @scenariosTypeInflation.
  ///
  /// In en, this message translates to:
  /// **'Different inflation'**
  String get scenariosTypeInflation;

  /// No description provided for @scenariosTypeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unsupported change'**
  String get scenariosTypeUnknown;

  /// No description provided for @scenariosSumOneOff.
  ///
  /// In en, this message translates to:
  /// **'One-off · {amount} on {date}'**
  String scenariosSumOneOff(String amount, String date);

  /// No description provided for @scenariosSumPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent} from {date}'**
  String scenariosSumPercent(String percent, String date);

  /// No description provided for @scenariosSumCategoryAbsolute.
  ///
  /// In en, this message translates to:
  /// **'{amount} per month from {date}'**
  String scenariosSumCategoryAbsolute(String amount, String date);

  /// No description provided for @scenariosSumRecurringAbsolute.
  ///
  /// In en, this message translates to:
  /// **'{amount} per payment from {date}'**
  String scenariosSumRecurringAbsolute(String amount, String date);

  /// No description provided for @scenariosSumAddRecurring.
  ///
  /// In en, this message translates to:
  /// **'{amount} {frequency} from {date}'**
  String scenariosSumAddRecurring(String amount, String frequency, String date);

  /// No description provided for @scenariosSumEndRecurring.
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String scenariosSumEndRecurring(Object date);

  /// No description provided for @scenariosSumReturnAll.
  ///
  /// In en, this message translates to:
  /// **'Return {percent} on investments'**
  String scenariosSumReturnAll(Object percent);

  /// No description provided for @scenariosSumReturnAccount.
  ///
  /// In en, this message translates to:
  /// **'Return {percent} on {account}'**
  String scenariosSumReturnAccount(String percent, String account);

  /// No description provided for @scenariosSumInflation.
  ///
  /// In en, this message translates to:
  /// **'Inflation {percent}'**
  String scenariosSumInflation(Object percent);

  /// No description provided for @scenariosUnknownItem.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get scenariosUnknownItem;

  /// No description provided for @scenariosFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get scenariosFieldLabel;

  /// No description provided for @scenariosFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get scenariosFieldDate;

  /// No description provided for @scenariosFieldFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get scenariosFieldFrom;

  /// No description provided for @scenariosFieldUntil.
  ///
  /// In en, this message translates to:
  /// **'Until (optional)'**
  String get scenariosFieldUntil;

  /// No description provided for @scenariosFieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get scenariosFieldAmount;

  /// No description provided for @scenariosFieldAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get scenariosFieldAccount;

  /// No description provided for @scenariosFieldTransferTo.
  ///
  /// In en, this message translates to:
  /// **'Transfer to (optional)'**
  String get scenariosFieldTransferTo;

  /// No description provided for @scenariosFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get scenariosFieldCategory;

  /// No description provided for @scenariosFieldRule.
  ///
  /// In en, this message translates to:
  /// **'Recurring item'**
  String get scenariosFieldRule;

  /// No description provided for @scenariosFieldChangeBy.
  ///
  /// In en, this message translates to:
  /// **'Change by'**
  String get scenariosFieldChangeBy;

  /// No description provided for @scenariosModePercent.
  ///
  /// In en, this message translates to:
  /// **'Percent'**
  String get scenariosModePercent;

  /// No description provided for @scenariosModeAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get scenariosModeAmount;

  /// No description provided for @scenariosFieldPercent.
  ///
  /// In en, this message translates to:
  /// **'Change in % (e.g. 5 or −10)'**
  String get scenariosFieldPercent;

  /// No description provided for @scenariosFieldDeltaMonthly.
  ///
  /// In en, this message translates to:
  /// **'Change per month (negative = less)'**
  String get scenariosFieldDeltaMonthly;

  /// No description provided for @scenariosFieldDeltaEach.
  ///
  /// In en, this message translates to:
  /// **'Change per payment (negative = less)'**
  String get scenariosFieldDeltaEach;

  /// No description provided for @scenariosFieldRepeats.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get scenariosFieldRepeats;

  /// No description provided for @scenariosFreqWeekly.
  ///
  /// In en, this message translates to:
  /// **'weekly'**
  String get scenariosFreqWeekly;

  /// No description provided for @scenariosFreqMonthly.
  ///
  /// In en, this message translates to:
  /// **'monthly'**
  String get scenariosFreqMonthly;

  /// No description provided for @scenariosFreqQuarterly.
  ///
  /// In en, this message translates to:
  /// **'every 3 months'**
  String get scenariosFreqQuarterly;

  /// No description provided for @scenariosFreqYearly.
  ///
  /// In en, this message translates to:
  /// **'yearly'**
  String get scenariosFreqYearly;

  /// No description provided for @scenariosFreqCustom.
  ///
  /// In en, this message translates to:
  /// **'custom'**
  String get scenariosFreqCustom;

  /// No description provided for @scenariosFieldReturn.
  ///
  /// In en, this message translates to:
  /// **'Expected return per year in %'**
  String get scenariosFieldReturn;

  /// No description provided for @scenariosFieldInflation.
  ///
  /// In en, this message translates to:
  /// **'Inflation per year in %'**
  String get scenariosFieldInflation;

  /// No description provided for @scenariosAllInvestments.
  ///
  /// In en, this message translates to:
  /// **'All investments'**
  String get scenariosAllInvestments;

  /// No description provided for @scenariosInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get scenariosInvalidNumber;

  /// No description provided for @scenariosRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get scenariosRequired;

  /// No description provided for @scenariosChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get scenariosChoose;

  /// No description provided for @scenariosNoRules.
  ///
  /// In en, this message translates to:
  /// **'There are no recurring items yet.'**
  String get scenariosNoRules;

  /// No description provided for @scenariosLowDelta.
  ///
  /// In en, this message translates to:
  /// **'Lowest {delta}'**
  String scenariosLowDelta(Object delta);

  /// No description provided for @scenariosEndDelta.
  ///
  /// In en, this message translates to:
  /// **'End {delta}'**
  String scenariosEndDelta(Object delta);

  /// No description provided for @scenariosResolvesWarning.
  ///
  /// In en, this message translates to:
  /// **'Stays above your threshold'**
  String get scenariosResolvesWarning;

  /// No description provided for @scenariosCausesWarning.
  ///
  /// In en, this message translates to:
  /// **'Drops below your threshold'**
  String get scenariosCausesWarning;

  /// No description provided for @securityLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiet Ledger is locked'**
  String get securityLockedTitle;

  /// No description provided for @securityEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get securityEnterPin;

  /// No description provided for @securityEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get securityEnterPassword;

  /// No description provided for @securityUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get securityUnlock;

  /// No description provided for @securityUseBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get securityUseBiometrics;

  /// No description provided for @securityBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Quiet Ledger'**
  String get securityBiometricReason;

  /// No description provided for @securityWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get securityWrongPin;

  /// No description provided for @securityWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get securityWrongPassword;

  /// No description provided for @securityAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attempt left before a delay} other{{count} attempts left before a delay}}'**
  String securityAttemptsLeft(int count);

  /// No description provided for @securityTryAgainIn.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {time}.'**
  String securityTryAgainIn(String time);

  /// No description provided for @securityChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get securityChecking;

  /// No description provided for @securityDeleteDigit.
  ///
  /// In en, this message translates to:
  /// **'Delete digit'**
  String get securityDeleteDigit;

  /// No description provided for @securityDigitsOf.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} digits entered'**
  String securityDigitsOf(int count, int total);

  /// No description provided for @securityDigitsEntered.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No digits entered} =1{1 digit entered} other{{count} digits entered}}'**
  String securityDigitsEntered(int count);

  /// No description provided for @securityPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get securityPasswordLabel;

  /// No description provided for @securityShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get securityShowPassword;

  /// No description provided for @securityHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get securityHidePassword;

  /// No description provided for @securitySetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up app lock'**
  String get securitySetupTitle;

  /// No description provided for @securityChooseMethod.
  ///
  /// In en, this message translates to:
  /// **'How do you want to unlock the app?'**
  String get securityChooseMethod;

  /// No description provided for @securityMethodPin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get securityMethodPin;

  /// No description provided for @securityMethodPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get securityMethodPassword;

  /// No description provided for @securityAlsoBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Also unlock with biometrics'**
  String get securityAlsoBiometrics;

  /// No description provided for @securityAlsoBiometricsDesc.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint, face or Windows Hello. Your PIN or password stays as a fallback.'**
  String get securityAlsoBiometricsDesc;

  /// No description provided for @securityNewPin.
  ///
  /// In en, this message translates to:
  /// **'Choose a PIN'**
  String get securityNewPin;

  /// No description provided for @securityConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN again'**
  String get securityConfirmPin;

  /// No description provided for @securityNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a password'**
  String get securityNewPassword;

  /// No description provided for @securityConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter the password again'**
  String get securityConfirmPassword;

  /// No description provided for @securityMismatch.
  ///
  /// In en, this message translates to:
  /// **'The entries don\'t match. Try again.'**
  String get securityMismatch;

  /// No description provided for @securityPinDigitsOnly.
  ///
  /// In en, this message translates to:
  /// **'Use digits only'**
  String get securityPinDigitsOnly;

  /// No description provided for @securityPinLength.
  ///
  /// In en, this message translates to:
  /// **'{min} to {max} digits'**
  String securityPinLength(int min, int max);

  /// No description provided for @securityPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters'**
  String securityPasswordTooShort(int min);

  /// No description provided for @securityChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get securityChangePin;

  /// No description provided for @securityChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get securityChangePassword;

  /// No description provided for @securityChangeDesc.
  ///
  /// In en, this message translates to:
  /// **'Or switch between PIN and password'**
  String get securityChangeDesc;

  /// No description provided for @securityLockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get securityLockNow;

  /// No description provided for @securityLockOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Require a PIN or password to open the app'**
  String get securityLockOffDesc;

  /// No description provided for @securityLockTimeoutDesc.
  ///
  /// In en, this message translates to:
  /// **'How long the app may stay in the background before it locks'**
  String get securityLockTimeoutDesc;

  /// No description provided for @securityConfirmIdentity.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you'**
  String get securityConfirmIdentity;

  /// No description provided for @securityCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get securityCurrentPin;

  /// No description provided for @securityCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get securityCurrentPassword;

  /// No description provided for @securityDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off app lock?'**
  String get securityDisableTitle;

  /// No description provided for @securityDisableMessage.
  ///
  /// In en, this message translates to:
  /// **'Anyone with access to this device can then open the app and see your finances.'**
  String get securityDisableMessage;

  /// No description provided for @securityTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get securityTurnOff;

  /// No description provided for @securityTimeoutImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get securityTimeoutImmediately;

  /// No description provided for @securityTimeoutSeconds.
  ///
  /// In en, this message translates to:
  /// **'{n} s'**
  String securityTimeoutSeconds(int n);

  /// No description provided for @securityTimeoutMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String securityTimeoutMinutes(int n);

  /// No description provided for @securityTimeoutHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h'**
  String securityTimeoutHours(int n);

  /// No description provided for @securityContentHidden.
  ///
  /// In en, this message translates to:
  /// **'Content hidden'**
  String get securityContentHidden;

  /// No description provided for @fieldAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get fieldAccount;

  /// No description provided for @fieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get fieldAmount;

  /// No description provided for @fieldBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get fieldBalance;

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @fieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get fieldNote;

  /// No description provided for @fieldPayee.
  ///
  /// In en, this message translates to:
  /// **'Payee'**
  String get fieldPayee;

  /// No description provided for @fieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get fieldStatus;

  /// No description provided for @setAccentScheme.
  ///
  /// In en, this message translates to:
  /// **'Accent colour'**
  String get setAccentScheme;

  /// No description provided for @setAmountColorStyle.
  ///
  /// In en, this message translates to:
  /// **'Amount colours'**
  String get setAmountColorStyle;

  /// No description provided for @setAppLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get setAppLock;

  /// No description provided for @setAutoExport.
  ///
  /// In en, this message translates to:
  /// **'Automatic export'**
  String get setAutoExport;

  /// No description provided for @setAutoExportFolder.
  ///
  /// In en, this message translates to:
  /// **'Export folder'**
  String get setAutoExportFolder;

  /// No description provided for @setAutoExportKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep last exports'**
  String get setAutoExportKeep;

  /// No description provided for @setBlockScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Block screenshots'**
  String get setBlockScreenshots;

  /// No description provided for @setBlockScreenshotsDesc.
  ///
  /// In en, this message translates to:
  /// **'Android only'**
  String get setBlockScreenshotsDesc;

  /// No description provided for @setBudgetMode.
  ///
  /// In en, this message translates to:
  /// **'Budget mode'**
  String get setBudgetMode;

  /// No description provided for @setCalculatorKeypad.
  ///
  /// In en, this message translates to:
  /// **'Calculator keypad'**
  String get setCalculatorKeypad;

  /// No description provided for @setCombineScenarios.
  ///
  /// In en, this message translates to:
  /// **'Show all scenarios combined'**
  String get setCombineScenarios;

  /// No description provided for @setCombineScenariosDesc.
  ///
  /// In en, this message translates to:
  /// **'Adds a line with all compared scenarios applied together. If several set a return or inflation rate, the last one wins.'**
  String get setCombineScenariosDesc;

  /// No description provided for @setConfirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm before deleting'**
  String get setConfirmDelete;

  /// No description provided for @setSidebarCollapsed.
  ///
  /// In en, this message translates to:
  /// **'Collapse the sidebar'**
  String get setSidebarCollapsed;

  /// No description provided for @setForecastSidePanelHidden.
  ///
  /// In en, this message translates to:
  /// **'Hide the forecast side panel'**
  String get setForecastSidePanelHidden;

  /// No description provided for @setCsvDateFormat.
  ///
  /// In en, this message translates to:
  /// **'CSV date format'**
  String get setCsvDateFormat;

  /// No description provided for @setCsvDecimalSeparator.
  ///
  /// In en, this message translates to:
  /// **'CSV decimal separator'**
  String get setCsvDecimalSeparator;

  /// No description provided for @setCsvDelimiter.
  ///
  /// In en, this message translates to:
  /// **'CSV delimiter'**
  String get setCsvDelimiter;

  /// No description provided for @setCsvEncoding.
  ///
  /// In en, this message translates to:
  /// **'CSV encoding'**
  String get setCsvEncoding;

  /// No description provided for @setCustomAccent.
  ///
  /// In en, this message translates to:
  /// **'Custom accent'**
  String get setCustomAccent;

  /// No description provided for @setDashboardPeriod.
  ///
  /// In en, this message translates to:
  /// **'Dashboard period'**
  String get setDashboardPeriod;

  /// No description provided for @setDashboardWidgets.
  ///
  /// In en, this message translates to:
  /// **'Dashboard widgets'**
  String get setDashboardWidgets;

  /// No description provided for @setDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get setDateFormat;

  /// No description provided for @setDefaultAccount.
  ///
  /// In en, this message translates to:
  /// **'Default account'**
  String get setDefaultAccount;

  /// No description provided for @setDefaultCategorySet.
  ///
  /// In en, this message translates to:
  /// **'Default categories'**
  String get setDefaultCategorySet;

  /// No description provided for @setDefaultDate.
  ///
  /// In en, this message translates to:
  /// **'Default date'**
  String get setDefaultDate;

  /// No description provided for @setDefaultFilter.
  ///
  /// In en, this message translates to:
  /// **'Default filter'**
  String get setDefaultFilter;

  /// No description provided for @setDefaultPostingMode.
  ///
  /// In en, this message translates to:
  /// **'Default posting mode'**
  String get setDefaultPostingMode;

  /// No description provided for @setDefaultReturn.
  ///
  /// In en, this message translates to:
  /// **'Default expected return'**
  String get setDefaultReturn;

  /// No description provided for @setDefaultReturnDesc.
  ///
  /// In en, this message translates to:
  /// **'Per year, for accounts without their own value'**
  String get setDefaultReturnDesc;

  /// No description provided for @setDefaultRollover.
  ///
  /// In en, this message translates to:
  /// **'Default rollover'**
  String get setDefaultRollover;

  /// No description provided for @setDefaultType.
  ///
  /// In en, this message translates to:
  /// **'Default type'**
  String get setDefaultType;

  /// No description provided for @setDensity.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get setDensity;

  /// No description provided for @setDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get setDeviceName;

  /// No description provided for @setDynamicColor.
  ///
  /// In en, this message translates to:
  /// **'Dynamic colour'**
  String get setDynamicColor;

  /// No description provided for @setDynamicColorDesc.
  ///
  /// In en, this message translates to:
  /// **'Use the system accent colour (Material You)'**
  String get setDynamicColorDesc;

  /// No description provided for @setExcludedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Excluded accounts'**
  String get setExcludedAccounts;

  /// No description provided for @setExcludedCategories.
  ///
  /// In en, this message translates to:
  /// **'Excluded categories'**
  String get setExcludedCategories;

  /// No description provided for @setExcludedTags.
  ///
  /// In en, this message translates to:
  /// **'Excluded tags'**
  String get setExcludedTags;

  /// No description provided for @setFieldOrder.
  ///
  /// In en, this message translates to:
  /// **'Quick-add field order'**
  String get setFieldOrder;

  /// No description provided for @setFirstDayOfWeek.
  ///
  /// In en, this message translates to:
  /// **'First day of week'**
  String get setFirstDayOfWeek;

  /// No description provided for @setFiscalYearStart.
  ///
  /// In en, this message translates to:
  /// **'Fiscal year starts in month'**
  String get setFiscalYearStart;

  /// No description provided for @setFiscalYearStartDesc.
  ///
  /// In en, this message translates to:
  /// **'1 = January'**
  String get setFiscalYearStartDesc;

  /// No description provided for @setFormatLocale.
  ///
  /// In en, this message translates to:
  /// **'Number & date format'**
  String get setFormatLocale;

  /// No description provided for @setFormatLocaleDesc.
  ///
  /// In en, this message translates to:
  /// **'Region used to format numbers and dates'**
  String get setFormatLocaleDesc;

  /// No description provided for @setGrouping.
  ///
  /// In en, this message translates to:
  /// **'Grouping'**
  String get setGrouping;

  /// No description provided for @setHideAmounts.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts'**
  String get setHideAmounts;

  /// No description provided for @setHideAmountsDesc.
  ///
  /// In en, this message translates to:
  /// **'Blur amounts until tapped'**
  String get setHideAmountsDesc;

  /// No description provided for @setHideInAppSwitcher.
  ///
  /// In en, this message translates to:
  /// **'Hide content in app switcher'**
  String get setHideInAppSwitcher;

  /// No description provided for @setHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get setHighContrast;

  /// No description provided for @setHolidayCountry.
  ///
  /// In en, this message translates to:
  /// **'Holiday calendar'**
  String get setHolidayCountry;

  /// No description provided for @setHolidayRegion.
  ///
  /// In en, this message translates to:
  /// **'Federal state'**
  String get setHolidayRegion;

  /// No description provided for @setHorizonMonths.
  ///
  /// In en, this message translates to:
  /// **'Forecast horizon (months)'**
  String get setHorizonMonths;

  /// No description provided for @setImportProfiles.
  ///
  /// In en, this message translates to:
  /// **'Import profiles & history'**
  String get setImportProfiles;

  /// No description provided for @setIncludePending.
  ///
  /// In en, this message translates to:
  /// **'Include pending'**
  String get setIncludePending;

  /// No description provided for @setIncludePlanned.
  ///
  /// In en, this message translates to:
  /// **'Include planned'**
  String get setIncludePlanned;

  /// No description provided for @setInflation.
  ///
  /// In en, this message translates to:
  /// **'Inflation rate'**
  String get setInflation;

  /// No description provided for @setLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get setLanguage;

  /// No description provided for @setLockMethod.
  ///
  /// In en, this message translates to:
  /// **'Unlock method'**
  String get setLockMethod;

  /// No description provided for @setLockOnStart.
  ///
  /// In en, this message translates to:
  /// **'Lock on start'**
  String get setLockOnStart;

  /// No description provided for @setLockTimeout.
  ///
  /// In en, this message translates to:
  /// **'Lock after (in background)'**
  String get setLockTimeout;

  /// No description provided for @setLowBalanceThreshold.
  ///
  /// In en, this message translates to:
  /// **'Low-balance threshold'**
  String get setLowBalanceThreshold;

  /// No description provided for @setManageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get setManageCategories;

  /// No description provided for @setManageCustomFields.
  ///
  /// In en, this message translates to:
  /// **'Manage custom fields'**
  String get setManageCustomFields;

  /// No description provided for @setManageTags.
  ///
  /// In en, this message translates to:
  /// **'Manage tags'**
  String get setManageTags;

  /// No description provided for @setModAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get setModAttachments;

  /// No description provided for @setModBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get setModBudgets;

  /// No description provided for @setModCustomFields.
  ///
  /// In en, this message translates to:
  /// **'Custom fields'**
  String get setModCustomFields;

  /// No description provided for @setNavTabs.
  ///
  /// In en, this message translates to:
  /// **'Navigation tabs'**
  String get setNavTabs;

  /// No description provided for @setNavTabsDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose and order the tabs'**
  String get setNavTabsDesc;

  /// No description provided for @setNotificationTime.
  ///
  /// In en, this message translates to:
  /// **'Notification time'**
  String get setNotificationTime;

  /// No description provided for @setNotifyBills.
  ///
  /// In en, this message translates to:
  /// **'Notify about bills'**
  String get setNotifyBills;

  /// No description provided for @setNotifyBudget.
  ///
  /// In en, this message translates to:
  /// **'Notify about budgets'**
  String get setNotifyBudget;

  /// No description provided for @setNotifyIncome.
  ///
  /// In en, this message translates to:
  /// **'Notify about income'**
  String get setNotifyIncome;

  /// No description provided for @setNotifyLowBalance.
  ///
  /// In en, this message translates to:
  /// **'Notify about low balance'**
  String get setNotifyLowBalance;

  /// No description provided for @setOnboardingDone.
  ///
  /// In en, this message translates to:
  /// **'Onboarding completed'**
  String get setOnboardingDone;

  /// No description provided for @setOptAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get setOptAmber;

  /// No description provided for @setOptAutoPost.
  ///
  /// In en, this message translates to:
  /// **'Post automatically'**
  String get setOptAutoPost;

  /// No description provided for @setOptBiWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every two weeks'**
  String get setOptBiWeekly;

  /// No description provided for @setOptBiometric.
  ///
  /// In en, this message translates to:
  /// **'Biometrics'**
  String get setOptBiometric;

  /// No description provided for @setOptBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get setOptBlue;

  /// No description provided for @setOptBudgetPeriod.
  ///
  /// In en, this message translates to:
  /// **'Budget period'**
  String get setOptBudgetPeriod;

  /// No description provided for @setOptCalendarMonth.
  ///
  /// In en, this message translates to:
  /// **'Calendar month'**
  String get setOptCalendarMonth;

  /// No description provided for @setOptColorCoded.
  ///
  /// In en, this message translates to:
  /// **'Colour-coded'**
  String get setOptColorCoded;

  /// No description provided for @setOptComfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get setOptComfortable;

  /// No description provided for @setOptComma.
  ///
  /// In en, this message translates to:
  /// **'comma'**
  String get setOptComma;

  /// No description provided for @setOptCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get setOptCompact;

  /// No description provided for @setOptCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get setOptCustom;

  /// No description provided for @setOptDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get setOptDaily;

  /// No description provided for @setOptDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get setOptDark;

  /// No description provided for @setOptDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get setOptDay;

  /// No description provided for @setOptEnvelope.
  ///
  /// In en, this message translates to:
  /// **'Envelope (zero-based)'**
  String get setOptEnvelope;

  /// No description provided for @setOptFromBudget.
  ///
  /// In en, this message translates to:
  /// **'From budget'**
  String get setOptFromBudget;

  /// No description provided for @setOptFromLanguage.
  ///
  /// In en, this message translates to:
  /// **'From language'**
  String get setOptFromLanguage;

  /// No description provided for @setOptLargestFirst.
  ///
  /// In en, this message translates to:
  /// **'Largest first'**
  String get setOptLargestFirst;

  /// No description provided for @setOptLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get setOptLastMonth;

  /// No description provided for @setOptLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get setOptLastUsed;

  /// No description provided for @setOptLastYear.
  ///
  /// In en, this message translates to:
  /// **'Last year'**
  String get setOptLastYear;

  /// No description provided for @setOptLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get setOptLight;

  /// No description provided for @setOptLocaleDefault.
  ///
  /// In en, this message translates to:
  /// **'Locale default'**
  String get setOptLocaleDefault;

  /// No description provided for @setOptMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get setOptMonday;

  /// No description provided for @setOptMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get setOptMonth;

  /// No description provided for @setOptMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get setOptMonthly;

  /// No description provided for @setOptNationwide.
  ///
  /// In en, this message translates to:
  /// **'Nationwide only'**
  String get setOptNationwide;

  /// No description provided for @setOptNeutral.
  ///
  /// In en, this message translates to:
  /// **'Neutral'**
  String get setOptNeutral;

  /// No description provided for @setOptNewestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get setOptNewestFirst;

  /// No description provided for @setOptNextBusinessDay.
  ///
  /// In en, this message translates to:
  /// **'Next business day'**
  String get setOptNextBusinessDay;

  /// No description provided for @setOptNoRollover.
  ///
  /// In en, this message translates to:
  /// **'No rollover'**
  String get setOptNoRollover;

  /// No description provided for @setOptNoShift.
  ///
  /// In en, this message translates to:
  /// **'Don\'t shift'**
  String get setOptNoShift;

  /// No description provided for @setOptOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get setOptOff;

  /// No description provided for @setOptOldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get setOptOldestFirst;

  /// No description provided for @setOptPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get setOptPassword;

  /// No description provided for @setOptPoint.
  ///
  /// In en, this message translates to:
  /// **'point'**
  String get setOptPoint;

  /// No description provided for @setOptPreviousBusinessDay.
  ///
  /// In en, this message translates to:
  /// **'Previous business day'**
  String get setOptPreviousBusinessDay;

  /// No description provided for @setOptQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get setOptQuarterly;

  /// No description provided for @setOptRemindConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remind & confirm'**
  String get setOptRemindConfirm;

  /// No description provided for @setOptRolloverBoth.
  ///
  /// In en, this message translates to:
  /// **'Leftover and overspent'**
  String get setOptRolloverBoth;

  /// No description provided for @setOptRolloverLeftover.
  ///
  /// In en, this message translates to:
  /// **'Carry leftover'**
  String get setOptRolloverLeftover;

  /// No description provided for @setOptRolloverOverspent.
  ///
  /// In en, this message translates to:
  /// **'Carry overspent'**
  String get setOptRolloverOverspent;

  /// No description provided for @setOptRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get setOptRose;

  /// No description provided for @setOptSaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get setOptSaturday;

  /// No description provided for @setOptSemicolon.
  ///
  /// In en, this message translates to:
  /// **'semicolon'**
  String get setOptSemicolon;

  /// No description provided for @setOptSignOnly.
  ///
  /// In en, this message translates to:
  /// **'+/− only'**
  String get setOptSignOnly;

  /// No description provided for @setOptSlate.
  ///
  /// In en, this message translates to:
  /// **'Slate'**
  String get setOptSlate;

  /// No description provided for @setOptSmallestFirst.
  ///
  /// In en, this message translates to:
  /// **'Smallest first'**
  String get setOptSmallestFirst;

  /// No description provided for @setOptSpruce.
  ///
  /// In en, this message translates to:
  /// **'Spruce'**
  String get setOptSpruce;

  /// No description provided for @setOptSunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get setOptSunday;

  /// No description provided for @setOptSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get setOptSystem;

  /// No description provided for @setOptThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get setOptThisMonth;

  /// No description provided for @setOptThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get setOptThisYear;

  /// No description provided for @setOptToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get setOptToday;

  /// No description provided for @setOptTracking.
  ///
  /// In en, this message translates to:
  /// **'Tracking (limits)'**
  String get setOptTracking;

  /// No description provided for @setOptViolet.
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get setOptViolet;

  /// No description provided for @setOptWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get setOptWeek;

  /// No description provided for @setOptWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get setOptWeekly;

  /// No description provided for @setOptYearToDate.
  ///
  /// In en, this message translates to:
  /// **'Year to date'**
  String get setOptYearToDate;

  /// No description provided for @setOptYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get setOptYearly;

  /// No description provided for @setPayeeSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Payee suggestions'**
  String get setPayeeSuggestions;

  /// No description provided for @setPayeeSuggestionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Learn category and account from history'**
  String get setPayeeSuggestionsDesc;

  /// No description provided for @setPeriodType.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get setPeriodType;

  /// No description provided for @setPrivacyOnStart.
  ///
  /// In en, this message translates to:
  /// **'Privacy mode on start'**
  String get setPrivacyOnStart;

  /// No description provided for @setProjectionYears.
  ///
  /// In en, this message translates to:
  /// **'Projection years'**
  String get setProjectionYears;

  /// No description provided for @setQuietHoursEnd.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours end'**
  String get setQuietHoursEnd;

  /// No description provided for @setQuietHoursStart.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours start'**
  String get setQuietHoursStart;

  /// No description provided for @setRealValues.
  ///
  /// In en, this message translates to:
  /// **'Show real values'**
  String get setRealValues;

  /// No description provided for @setRealValuesDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjust projections for inflation'**
  String get setRealValuesDesc;

  /// No description provided for @setRecentCategories.
  ///
  /// In en, this message translates to:
  /// **'Recent categories shown'**
  String get setRecentCategories;

  /// No description provided for @setReminderLeadDays.
  ///
  /// In en, this message translates to:
  /// **'Remind days before'**
  String get setReminderLeadDays;

  /// No description provided for @setReportPeriod.
  ///
  /// In en, this message translates to:
  /// **'Default period'**
  String get setReportPeriod;

  /// No description provided for @setRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Required fields'**
  String get setRequiredFields;

  /// No description provided for @setRunningBalance.
  ///
  /// In en, this message translates to:
  /// **'Running balance'**
  String get setRunningBalance;

  /// No description provided for @setRunningBalanceDesc.
  ///
  /// In en, this message translates to:
  /// **'Show the balance after each transaction'**
  String get setRunningBalanceDesc;

  /// No description provided for @setSalaryBased.
  ///
  /// In en, this message translates to:
  /// **'Start on payday'**
  String get setSalaryBased;

  /// No description provided for @setSalaryBasedDesc.
  ///
  /// In en, this message translates to:
  /// **'The period starts when the chosen income arrives'**
  String get setSalaryBasedDesc;

  /// No description provided for @setShowOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Show planned and upcoming'**
  String get setShowOutstanding;

  /// No description provided for @setShowOutstandingDesc.
  ///
  /// In en, this message translates to:
  /// **'Planned entries and recurring items not booked yet appear in budgets, marked as outstanding'**
  String get setShowOutstandingDesc;

  /// No description provided for @setSalaryRule.
  ///
  /// In en, this message translates to:
  /// **'Salary income'**
  String get setSalaryRule;

  /// No description provided for @setSecAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get setSecAppearance;

  /// No description provided for @setSecBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get setSecBudgets;

  /// No description provided for @setSecCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories & tags'**
  String get setSecCategories;

  /// No description provided for @setSecDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get setSecDashboard;

  /// No description provided for @setSecData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get setSecData;

  /// No description provided for @setSecEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get setSecEntry;

  /// No description provided for @setSecForecast.
  ///
  /// In en, this message translates to:
  /// **'Forecast & projection'**
  String get setSecForecast;

  /// No description provided for @setSecGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get setSecGeneral;

  /// No description provided for @setSecImportExport.
  ///
  /// In en, this message translates to:
  /// **'Import / export'**
  String get setSecImportExport;

  /// No description provided for @setSecNavigation.
  ///
  /// In en, this message translates to:
  /// **'Navigation & modules'**
  String get setSecNavigation;

  /// No description provided for @setSecPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get setSecPrivacy;

  /// No description provided for @setSecRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring & reminders'**
  String get setSecRecurring;

  /// No description provided for @setSecSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get setSecSecurity;

  /// No description provided for @setShowCents.
  ///
  /// In en, this message translates to:
  /// **'Show cents'**
  String get setShowCents;

  /// No description provided for @setSignStyle.
  ///
  /// In en, this message translates to:
  /// **'Negative amounts'**
  String get setSignStyle;

  /// No description provided for @setSort.
  ///
  /// In en, this message translates to:
  /// **'Sort order'**
  String get setSort;

  /// No description provided for @setStartDay.
  ///
  /// In en, this message translates to:
  /// **'Start day of month'**
  String get setStartDay;

  /// No description provided for @setStartDayDesc.
  ///
  /// In en, this message translates to:
  /// **'0 = last day of the month'**
  String get setStartDayDesc;

  /// No description provided for @setStartScreen.
  ///
  /// In en, this message translates to:
  /// **'Start screen'**
  String get setStartScreen;

  /// No description provided for @setStorageLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage location'**
  String get setStorageLocation;

  /// No description provided for @setTextScale.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get setTextScale;

  /// No description provided for @setThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get setThemeMode;

  /// No description provided for @setTombstoneDays.
  ///
  /// In en, this message translates to:
  /// **'Keep deleted items (days)'**
  String get setTombstoneDays;

  /// No description provided for @setTombstoneDaysDesc.
  ///
  /// In en, this message translates to:
  /// **'Needed later for sync'**
  String get setTombstoneDaysDesc;

  /// No description provided for @setUpcomingDays.
  ///
  /// In en, this message translates to:
  /// **'Upcoming bills window (days)'**
  String get setUpcomingDays;

  /// No description provided for @setVariableMethod.
  ///
  /// In en, this message translates to:
  /// **'Variable spending estimate'**
  String get setVariableMethod;

  /// No description provided for @setVisibleColumns.
  ///
  /// In en, this message translates to:
  /// **'Visible columns'**
  String get setVisibleColumns;

  /// No description provided for @setWarnThreshold.
  ///
  /// In en, this message translates to:
  /// **'Warning threshold'**
  String get setWarnThreshold;

  /// No description provided for @setWeekendShift.
  ///
  /// In en, this message translates to:
  /// **'Weekend & holiday shift'**
  String get setWeekendShift;

  /// No description provided for @setModuleEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable {module}'**
  String setModuleEnabled(String module);

  /// No description provided for @setOptMean.
  ///
  /// In en, this message translates to:
  /// **'Average of last {n} months'**
  String setOptMean(int n);

  /// No description provided for @setOptMedian.
  ///
  /// In en, this message translates to:
  /// **'Median of last {n} months'**
  String setOptMedian(int n);

  /// No description provided for @setOptLastNMonths.
  ///
  /// In en, this message translates to:
  /// **'Last {n} months'**
  String setOptLastNMonths(int n);

  /// No description provided for @setSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get setSettingsTitle;

  /// No description provided for @settingsUiSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsUiSearchHint;

  /// No description provided for @settingsUiNoResults.
  ///
  /// In en, this message translates to:
  /// **'No settings match “{query}”'**
  String settingsUiNoResults(String query);

  /// No description provided for @settingsUiClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsUiClear;

  /// No description provided for @settingsUiSecAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsUiSecAbout;

  /// No description provided for @settingsUiAboutSummary.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsUiAboutSummary(String version);

  /// No description provided for @settingsUiAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsUiAboutVersion;

  /// No description provided for @settingsUiAboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get settingsUiAboutLicenses;

  /// No description provided for @settingsUiAboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'All data stays on this device. No account, no telemetry.'**
  String get settingsUiAboutPrivacy;

  /// No description provided for @settingsUiAboutEncryption.
  ///
  /// In en, this message translates to:
  /// **'Database encryption'**
  String get settingsUiAboutEncryption;

  /// No description provided for @settingsUiAboutEncryptionOn.
  ///
  /// In en, this message translates to:
  /// **'On (SQLite3 Multiple Ciphers, key in the system keystore)'**
  String get settingsUiAboutEncryptionOn;

  /// No description provided for @settingsUiAboutEncryptionOff.
  ///
  /// In en, this message translates to:
  /// **'Off: no secure key storage was available when the database was created'**
  String get settingsUiAboutEncryptionOff;

  /// No description provided for @settingsUiAboutEncryptionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this platform'**
  String get settingsUiAboutEncryptionUnavailable;

  /// No description provided for @settingsUiAmountsHidden.
  ///
  /// In en, this message translates to:
  /// **'Amounts hidden'**
  String get settingsUiAmountsHidden;

  /// No description provided for @settingsUiAmountsVisible.
  ///
  /// In en, this message translates to:
  /// **'Amounts visible'**
  String get settingsUiAmountsVisible;

  /// No description provided for @settingsUiTabsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tab} other{{count} tabs}}'**
  String settingsUiTabsCount(int count);

  /// No description provided for @settingsUiDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{On the day} =1{1 day before} other{{count} days before}}'**
  String settingsUiDaysBefore(int count);

  /// No description provided for @settingsUiMonthsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String settingsUiMonthsCount(int count);

  /// No description provided for @settingsUiModuleOff.
  ///
  /// In en, this message translates to:
  /// **'Module off'**
  String get settingsUiModuleOff;

  /// No description provided for @settingsUiModuleOffNotice.
  ///
  /// In en, this message translates to:
  /// **'The {module} module is switched off.'**
  String settingsUiModuleOffNotice(String module);

  /// No description provided for @settingsUiTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get settingsUiTurnOn;

  /// No description provided for @settingsUiDataSummary.
  ///
  /// In en, this message translates to:
  /// **'Storage, statistics, reset'**
  String get settingsUiDataSummary;

  /// No description provided for @settingsUiResetSection.
  ///
  /// In en, this message translates to:
  /// **'Reset section'**
  String get settingsUiResetSection;

  /// No description provided for @settingsUiResetSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset “{section}”?'**
  String settingsUiResetSectionTitle(String section);

  /// No description provided for @settingsUiResetSectionMessage.
  ///
  /// In en, this message translates to:
  /// **'All settings in this section return to their defaults.'**
  String get settingsUiResetSectionMessage;

  /// No description provided for @settingsUiResetDone.
  ///
  /// In en, this message translates to:
  /// **'Section reset'**
  String get settingsUiResetDone;

  /// No description provided for @settingsUiModulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get settingsUiModulesTitle;

  /// No description provided for @settingsUiModulesDesc.
  ///
  /// In en, this message translates to:
  /// **'Switched-off modules disappear from navigation and settings. Their data is kept.'**
  String get settingsUiModulesDesc;

  /// No description provided for @settingsUiNavTabsHint.
  ///
  /// In en, this message translates to:
  /// **'{min} to {max} tabs, “More” is always last'**
  String settingsUiNavTabsHint(int min, int max);

  /// No description provided for @settingsUiNavTabsRecommend.
  ///
  /// In en, this message translates to:
  /// **'Tip: keep Home or Transactions in the bar.'**
  String get settingsUiNavTabsRecommend;

  /// No description provided for @settingsUiNavTabModuleOff.
  ///
  /// In en, this message translates to:
  /// **'Hidden while the module is switched off'**
  String get settingsUiNavTabModuleOff;

  /// No description provided for @settingsUiNavMoreAlways.
  ///
  /// In en, this message translates to:
  /// **'Always shown, always last'**
  String get settingsUiNavMoreAlways;

  /// No description provided for @settingsUiDragHandle.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get settingsUiDragHandle;

  /// No description provided for @settingsUiMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get settingsUiMoveUp;

  /// No description provided for @settingsUiMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get settingsUiMoveDown;

  /// No description provided for @settingsUiNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get settingsUiNotSet;

  /// No description provided for @settingsUiAndMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String settingsUiAndMore(int count);

  /// No description provided for @settingsUiLastDay.
  ///
  /// In en, this message translates to:
  /// **'Last day'**
  String get settingsUiLastDay;

  /// No description provided for @settingsUiDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get settingsUiDecrease;

  /// No description provided for @settingsUiIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get settingsUiIncrease;

  /// No description provided for @settingsUiTapToType.
  ///
  /// In en, this message translates to:
  /// **'Double-tap to type a value'**
  String get settingsUiTapToType;

  /// No description provided for @settingsUiInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number'**
  String get settingsUiInvalidNumber;

  /// No description provided for @settingsUiInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'This value is not allowed'**
  String get settingsUiInvalidValue;

  /// No description provided for @settingsUiOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a value from {min} to {max}'**
  String settingsUiOutOfRange(int min, int max);

  /// No description provided for @settingsUiOutOfRangeText.
  ///
  /// In en, this message translates to:
  /// **'From {min} to {max}'**
  String settingsUiOutOfRangeText(String min, String max);

  /// No description provided for @settingsUiPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get settingsUiPresets;

  /// No description provided for @settingsUiCustomColor.
  ///
  /// In en, this message translates to:
  /// **'Custom colour'**
  String get settingsUiCustomColor;

  /// No description provided for @settingsUiHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get settingsUiHue;

  /// No description provided for @settingsUiSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get settingsUiSaturation;

  /// No description provided for @settingsUiLightness.
  ///
  /// In en, this message translates to:
  /// **'Lightness'**
  String get settingsUiLightness;

  /// No description provided for @settingsUiHex.
  ///
  /// In en, this message translates to:
  /// **'HEX'**
  String get settingsUiHex;

  /// No description provided for @settingsUiInvalidHex.
  ///
  /// In en, this message translates to:
  /// **'Enter a colour like #1F5A53'**
  String get settingsUiInvalidHex;

  /// No description provided for @settingsUiNoTags.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get settingsUiNoTags;

  /// No description provided for @settingsUiPrivacyNow.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts now'**
  String get settingsUiPrivacyNow;

  /// No description provided for @settingsUiPrivacyNowDesc.
  ///
  /// In en, this message translates to:
  /// **'Privacy mode for this session'**
  String get settingsUiPrivacyNowDesc;

  /// No description provided for @settingsUiStats.
  ///
  /// In en, this message translates to:
  /// **'Database statistics'**
  String get settingsUiStats;

  /// No description provided for @settingsUiStatRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring rules'**
  String get settingsUiStatRecurring;

  /// No description provided for @settingsUiStatImports.
  ///
  /// In en, this message translates to:
  /// **'Imports'**
  String get settingsUiStatImports;

  /// No description provided for @settingsUiStatChangeLog.
  ///
  /// In en, this message translates to:
  /// **'Change log entries'**
  String get settingsUiStatChangeLog;

  /// No description provided for @settingsUiStatDbSize.
  ///
  /// In en, this message translates to:
  /// **'Database size'**
  String get settingsUiStatDbSize;

  /// No description provided for @settingsUiRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get settingsUiRefresh;

  /// No description provided for @settingsUiRebuildIndex.
  ///
  /// In en, this message translates to:
  /// **'Rebuild search index'**
  String get settingsUiRebuildIndex;

  /// No description provided for @settingsUiRebuildIndexDesc.
  ///
  /// In en, this message translates to:
  /// **'Fixes missing or outdated search results'**
  String get settingsUiRebuildIndexDesc;

  /// No description provided for @settingsUiRebuildDone.
  ///
  /// In en, this message translates to:
  /// **'Search index rebuilt'**
  String get settingsUiRebuildDone;

  /// No description provided for @settingsUiRerunRules.
  ///
  /// In en, this message translates to:
  /// **'Re-run rules'**
  String get settingsUiRerunRules;

  /// No description provided for @settingsUiRerunRulesDesc.
  ///
  /// In en, this message translates to:
  /// **'Apply your categorisation rules to existing transactions'**
  String get settingsUiRerunRulesDesc;

  /// No description provided for @settingsUiRerunRulesAll.
  ///
  /// In en, this message translates to:
  /// **'Re-evaluate all transactions'**
  String get settingsUiRerunRulesAll;

  /// No description provided for @settingsUiRerunRulesAllDesc.
  ///
  /// In en, this message translates to:
  /// **'Rule values replace existing categories, not only empty ones'**
  String get settingsUiRerunRulesAllDesc;

  /// No description provided for @settingsUiRerunRulesDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No transactions changed} =1{1 transaction changed} other{{count} transactions changed}}'**
  String settingsUiRerunRulesDone(int count);

  /// No description provided for @settingsUiRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get settingsUiRun;

  /// No description provided for @settingsUiResetApp.
  ///
  /// In en, this message translates to:
  /// **'Reset app'**
  String get settingsUiResetApp;

  /// No description provided for @settingsUiResetAppDesc.
  ///
  /// In en, this message translates to:
  /// **'Delete all data on this device and start over'**
  String get settingsUiResetAppDesc;

  /// No description provided for @settingsUiResetAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all data?'**
  String get settingsUiResetAppTitle;

  /// No description provided for @settingsUiResetAppMessage.
  ///
  /// In en, this message translates to:
  /// **'This deletes every account, transaction, budget, rule and setting on this device, and the app lock. Type {word} to confirm.'**
  String settingsUiResetAppMessage(String word);

  /// No description provided for @settingsUiResetAppWord.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get settingsUiResetAppWord;

  /// No description provided for @settingsUiTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {word}'**
  String settingsUiTypeToConfirm(String word);

  /// No description provided for @settingsUiResetAppConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get settingsUiResetAppConfirm;

  /// No description provided for @settingsUiStorageDefault.
  ///
  /// In en, this message translates to:
  /// **'Default app folder'**
  String get settingsUiStorageDefault;

  /// No description provided for @settingsUiStorageMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Change storage location?'**
  String get settingsUiStorageMoveTitle;

  /// No description provided for @settingsUiStorageMoveMessage.
  ///
  /// In en, this message translates to:
  /// **'The current database is copied to {path} and used from there after the next restart. The old file stays where it is.'**
  String settingsUiStorageMoveMessage(String path);

  /// No description provided for @settingsUiStorageExisting.
  ///
  /// In en, this message translates to:
  /// **'{path} already contains a database. It will be used after the next restart; nothing is copied. It must have been created with this installation, otherwise it cannot be opened.'**
  String settingsUiStorageExisting(String path);

  /// No description provided for @settingsUiStorageCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy and switch'**
  String get settingsUiStorageCopy;

  /// No description provided for @settingsUiStorageUseExisting.
  ///
  /// In en, this message translates to:
  /// **'Use this database'**
  String get settingsUiStorageUseExisting;

  /// No description provided for @settingsUiStorageRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart the app to use the new location.'**
  String get settingsUiStorageRestart;

  /// No description provided for @settingsUiStorageResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Use default folder'**
  String get settingsUiStorageResetDefault;

  /// No description provided for @settingsUiStorageResetMessage.
  ///
  /// In en, this message translates to:
  /// **'After the next restart the app uses the database in its default folder again. Data stored in the custom folder is not copied back.'**
  String get settingsUiStorageResetMessage;

  /// No description provided for @settingsUiStatDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted items kept for sync'**
  String get settingsUiStatDeleted;

  /// No description provided for @settingsUiPurge.
  ///
  /// In en, this message translates to:
  /// **'Purge deleted items'**
  String get settingsUiPurge;

  /// No description provided for @settingsUiPurgeDesc.
  ///
  /// In en, this message translates to:
  /// **'Remove items deleted more than {days} days ago'**
  String settingsUiPurgeDesc(int days);

  /// No description provided for @settingsUiPurgeMessage.
  ///
  /// In en, this message translates to:
  /// **'Permanently removes items that were deleted more than {days} days ago. They can no longer be restored or synced.'**
  String settingsUiPurgeMessage(int days);

  /// No description provided for @settingsUiPurgeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Purge'**
  String get settingsUiPurgeConfirm;

  /// No description provided for @settingsUiPurgeDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing to purge} =1{1 item removed} other{{count} items removed}}'**
  String settingsUiPurgeDone(int count);

  /// No description provided for @txnSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search payee, note, category'**
  String get txnSearchHint;

  /// No description provided for @txnSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get txnSearchLabel;

  /// No description provided for @txnSearchHintWide.
  ///
  /// In en, this message translates to:
  /// **'Payee, note, tag, category'**
  String get txnSearchHintWide;

  /// No description provided for @txnSelectMultiple.
  ///
  /// In en, this message translates to:
  /// **'Select multiple'**
  String get txnSelectMultiple;

  /// No description provided for @txnNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get txnNew;

  /// No description provided for @txnCtrl.
  ///
  /// In en, this message translates to:
  /// **'Ctrl'**
  String get txnCtrl;

  /// No description provided for @txnEntries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String txnEntries(int count);

  /// No description provided for @txnIn.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get txnIn;

  /// No description provided for @txnOut.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get txnOut;

  /// No description provided for @txnToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get txnToday;

  /// No description provided for @txnYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get txnYesterday;

  /// No description provided for @txnTodayDate.
  ///
  /// In en, this message translates to:
  /// **'Today, {date}'**
  String txnTodayDate(String date);

  /// No description provided for @txnYesterdayDate.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {date}'**
  String txnYesterdayDate(String date);

  /// No description provided for @txnGroupToday.
  ///
  /// In en, this message translates to:
  /// **'Today · {date}'**
  String txnGroupToday(String date);

  /// No description provided for @txnGroupYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday · {date}'**
  String txnGroupYesterday(String date);

  /// No description provided for @txnTransferTo.
  ///
  /// In en, this message translates to:
  /// **'To {account}'**
  String txnTransferTo(String account);

  /// No description provided for @txnTransferFrom.
  ///
  /// In en, this message translates to:
  /// **'From {account}'**
  String txnTransferFrom(String account);

  /// No description provided for @txnTransferFromSub.
  ///
  /// In en, this message translates to:
  /// **'Transfer · from {account}'**
  String txnTransferFromSub(String account);

  /// No description provided for @txnTransferToSub.
  ///
  /// In en, this message translates to:
  /// **'Transfer · to {account}'**
  String txnTransferToSub(String account);

  /// No description provided for @txnSplitCount.
  ///
  /// In en, this message translates to:
  /// **'Split · {count}'**
  String txnSplitCount(int count);

  /// No description provided for @txnNoPayee.
  ///
  /// In en, this message translates to:
  /// **'No payee'**
  String get txnNoPayee;

  /// No description provided for @txnUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get txnUncategorized;

  /// No description provided for @txnUnknownAccount.
  ///
  /// In en, this message translates to:
  /// **'Unknown account'**
  String get txnUnknownAccount;

  /// No description provided for @txnHasReceipt.
  ///
  /// In en, this message translates to:
  /// **'Has receipt'**
  String get txnHasReceipt;

  /// No description provided for @txnRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get txnRecurring;

  /// No description provided for @txnBalanceShort.
  ///
  /// In en, this message translates to:
  /// **'Bal. {amount}'**
  String txnBalanceShort(String amount);

  /// No description provided for @txnEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet. Add your first one with the + button.'**
  String get txnEmpty;

  /// No description provided for @txnEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No transactions match these filters.'**
  String get txnEmptyFiltered;

  /// No description provided for @txnClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get txnClearFilters;

  /// No description provided for @txnFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get txnFilters;

  /// No description provided for @txnFilterAllDates.
  ///
  /// In en, this message translates to:
  /// **'All dates'**
  String get txnFilterAllDates;

  /// No description provided for @txnFilterType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get txnFilterType;

  /// No description provided for @txnFilterTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get txnFilterTag;

  /// No description provided for @txnFilterCustomField.
  ///
  /// In en, this message translates to:
  /// **'Custom field'**
  String get txnFilterCustomField;

  /// No description provided for @txnChipCount.
  ///
  /// In en, this message translates to:
  /// **'{label} · {count}'**
  String txnChipCount(String label, int count);

  /// No description provided for @txnSaveFilter.
  ///
  /// In en, this message translates to:
  /// **'Save filter'**
  String get txnSaveFilter;

  /// No description provided for @txnPresetThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get txnPresetThisMonth;

  /// No description provided for @txnPresetLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get txnPresetLastMonth;

  /// No description provided for @txnPresetLast30.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get txnPresetLast30;

  /// No description provided for @txnPresetLast90.
  ///
  /// In en, this message translates to:
  /// **'Last 90 days'**
  String get txnPresetLast90;

  /// No description provided for @txnPresetThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get txnPresetThisYear;

  /// No description provided for @txnPresetLastYear.
  ///
  /// In en, this message translates to:
  /// **'Last year'**
  String get txnPresetLastYear;

  /// No description provided for @txnPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom range…'**
  String get txnPresetCustom;

  /// No description provided for @txnAmountMin.
  ///
  /// In en, this message translates to:
  /// **'At least'**
  String get txnAmountMin;

  /// No description provided for @txnAmountMax.
  ///
  /// In en, this message translates to:
  /// **'At most'**
  String get txnAmountMax;

  /// No description provided for @txnAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Compares the amount without sign.'**
  String get txnAmountHint;

  /// No description provided for @txnAmountAtLeast.
  ///
  /// In en, this message translates to:
  /// **'≥ {amount}'**
  String txnAmountAtLeast(String amount);

  /// No description provided for @txnAmountAtMost.
  ///
  /// In en, this message translates to:
  /// **'≤ {amount}'**
  String txnAmountAtMost(String amount);

  /// No description provided for @txnApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get txnApply;

  /// No description provided for @txnChooseCategories.
  ///
  /// In en, this message translates to:
  /// **'Choose categories'**
  String get txnChooseCategories;

  /// No description provided for @txnCustomFieldAny.
  ///
  /// In en, this message translates to:
  /// **'Has any value'**
  String get txnCustomFieldAny;

  /// No description provided for @txnCustomFieldEquals.
  ///
  /// In en, this message translates to:
  /// **'Is'**
  String get txnCustomFieldEquals;

  /// No description provided for @txnCustomFieldContains.
  ///
  /// In en, this message translates to:
  /// **'Contains'**
  String get txnCustomFieldContains;

  /// No description provided for @txnCustomFieldIncludes.
  ///
  /// In en, this message translates to:
  /// **'Includes'**
  String get txnCustomFieldIncludes;

  /// No description provided for @txnCustomFieldValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get txnCustomFieldValue;

  /// No description provided for @txnCustomFieldAdd.
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get txnCustomFieldAdd;

  /// No description provided for @txnCustomFieldChoose.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get txnCustomFieldChoose;

  /// No description provided for @txnCustomFieldNone.
  ///
  /// In en, this message translates to:
  /// **'No custom fields for transactions yet.'**
  String get txnCustomFieldNone;

  /// No description provided for @txnSavedFilters.
  ///
  /// In en, this message translates to:
  /// **'Saved filters'**
  String get txnSavedFilters;

  /// No description provided for @txnAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'All transactions'**
  String get txnAllTransactions;

  /// No description provided for @txnFilterName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get txnFilterName;

  /// No description provided for @txnFilterSaved.
  ///
  /// In en, this message translates to:
  /// **'Filter saved'**
  String get txnFilterSaved;

  /// No description provided for @txnFilterUpdated.
  ///
  /// In en, this message translates to:
  /// **'Filter updated'**
  String get txnFilterUpdated;

  /// No description provided for @txnUpdateFilter.
  ///
  /// In en, this message translates to:
  /// **'Update with current filter'**
  String get txnUpdateFilter;

  /// No description provided for @txnRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get txnRename;

  /// No description provided for @txnSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Use as default'**
  String get txnSetDefault;

  /// No description provided for @txnUnsetDefault.
  ///
  /// In en, this message translates to:
  /// **'Stop using as default'**
  String get txnUnsetDefault;

  /// No description provided for @txnIsDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get txnIsDefault;

  /// No description provided for @txnFilterDeleted.
  ///
  /// In en, this message translates to:
  /// **'Filter deleted'**
  String get txnFilterDeleted;

  /// No description provided for @txnNoSavedFilters.
  ///
  /// In en, this message translates to:
  /// **'No saved filters yet. Set filters in the transaction list and tap “Save filter”.'**
  String get txnNoSavedFilters;

  /// No description provided for @txnNoDefaultFilter.
  ///
  /// In en, this message translates to:
  /// **'No default filter'**
  String get txnNoDefaultFilter;

  /// No description provided for @txnNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get txnNameRequired;

  /// No description provided for @txnViewOptions.
  ///
  /// In en, this message translates to:
  /// **'View options'**
  String get txnViewOptions;

  /// No description provided for @txnGroupingOffHint.
  ///
  /// In en, this message translates to:
  /// **'Grouping applies when sorted by date.'**
  String get txnGroupingOffHint;

  /// No description provided for @txnRunningBalanceHint.
  ///
  /// In en, this message translates to:
  /// **'The running balance is shown when the list is filtered to one account and sorted by date.'**
  String get txnRunningBalanceHint;

  /// No description provided for @txnChooseAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Choose account'**
  String get txnChooseAccountAction;

  /// No description provided for @txnSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String txnSelectedCount(int count);

  /// No description provided for @txnSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get txnSelectAll;

  /// No description provided for @txnClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get txnClearSelection;

  /// No description provided for @txnSetCategory.
  ///
  /// In en, this message translates to:
  /// **'Set category'**
  String get txnSetCategory;

  /// No description provided for @txnSetStatus.
  ///
  /// In en, this message translates to:
  /// **'Set status'**
  String get txnSetStatus;

  /// No description provided for @txnSetDate.
  ///
  /// In en, this message translates to:
  /// **'Set date'**
  String get txnSetDate;

  /// No description provided for @txnSetAccount.
  ///
  /// In en, this message translates to:
  /// **'Move to account'**
  String get txnSetAccount;

  /// No description provided for @txnAddTags.
  ///
  /// In en, this message translates to:
  /// **'Add tags'**
  String get txnAddTags;

  /// No description provided for @txnBulkUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction updated} other{{count} transactions updated}}'**
  String txnBulkUpdated(int count);

  /// No description provided for @txnDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Transaction deleted} other{{count} transactions deleted}}'**
  String txnDeleted(int count);

  /// No description provided for @txnDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete this transaction?} other{Delete {count} transactions?}}'**
  String txnDeleteConfirmTitle(int count);

  /// No description provided for @txnDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You can undo this right afterwards.'**
  String get txnDeleteConfirmBody;

  /// No description provided for @txnDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get txnDuplicate;

  /// No description provided for @txnDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Transaction duplicated'**
  String get txnDuplicated;

  /// No description provided for @txnMarkCleared.
  ///
  /// In en, this message translates to:
  /// **'Mark as cleared'**
  String get txnMarkCleared;

  /// No description provided for @txnMarkPending.
  ///
  /// In en, this message translates to:
  /// **'Mark as pending'**
  String get txnMarkPending;

  /// No description provided for @txnStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'Status changed'**
  String get txnStatusChanged;

  /// No description provided for @txnSaveAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as template'**
  String get txnSaveAsTemplate;

  /// No description provided for @txnTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved'**
  String get txnTemplateSaved;

  /// No description provided for @txnOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get txnOpen;

  /// No description provided for @txnSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get txnSelect;

  /// No description provided for @txnMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get txnMoreActions;

  /// No description provided for @txnDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get txnDetailTitle;

  /// No description provided for @txnEditTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get txnEditTransaction;

  /// No description provided for @txnCloseDetail.
  ///
  /// In en, this message translates to:
  /// **'Close detail'**
  String get txnCloseDetail;

  /// No description provided for @txnNotFound.
  ///
  /// In en, this message translates to:
  /// **'This transaction no longer exists.'**
  String get txnNotFound;

  /// No description provided for @txnSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get txnSplit;

  /// No description provided for @txnCustomFields.
  ///
  /// In en, this message translates to:
  /// **'Custom fields'**
  String get txnCustomFields;

  /// No description provided for @txnAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get txnAttachments;

  /// No description provided for @txnAttachmentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Attachment · 1 file} other{Attachments · {count} files}}'**
  String txnAttachmentCount(int count);

  /// No description provided for @txnAddAttachment.
  ///
  /// In en, this message translates to:
  /// **'Add attachment'**
  String get txnAddAttachment;

  /// No description provided for @txnAttachReceipt.
  ///
  /// In en, this message translates to:
  /// **'Attach receipt'**
  String get txnAttachReceipt;

  /// No description provided for @txnRemoveAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment {name}'**
  String txnRemoveAttachment(String name);

  /// No description provided for @txnAttachmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The file is not available on this device.'**
  String get txnAttachmentUnavailable;

  /// No description provided for @txnAttachmentPending.
  ///
  /// In en, this message translates to:
  /// **'Saved with the transaction'**
  String get txnAttachmentPending;

  /// No description provided for @txnShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get txnShare;

  /// No description provided for @txnOrigin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get txnOrigin;

  /// No description provided for @txnOriginRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring: {name}'**
  String txnOriginRecurring(String name);

  /// No description provided for @txnOriginImport.
  ///
  /// In en, this message translates to:
  /// **'Imported from {file}'**
  String txnOriginImport(String file);

  /// No description provided for @txnOriginManual.
  ///
  /// In en, this message translates to:
  /// **'Entered manually'**
  String get txnOriginManual;

  /// No description provided for @txnValueDate.
  ///
  /// In en, this message translates to:
  /// **'Value date'**
  String get txnValueDate;

  /// No description provided for @txnNewTransaction.
  ///
  /// In en, this message translates to:
  /// **'New transaction'**
  String get txnNewTransaction;

  /// No description provided for @txnNewTemplate.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get txnNewTemplate;

  /// No description provided for @txnEditTemplate.
  ///
  /// In en, this message translates to:
  /// **'Edit template'**
  String get txnEditTemplate;

  /// No description provided for @txnSaveExpense.
  ///
  /// In en, this message translates to:
  /// **'Save expense'**
  String get txnSaveExpense;

  /// No description provided for @txnSaveIncome.
  ///
  /// In en, this message translates to:
  /// **'Save income'**
  String get txnSaveIncome;

  /// No description provided for @txnSaveTransfer.
  ///
  /// In en, this message translates to:
  /// **'Save transfer'**
  String get txnSaveTransfer;

  /// No description provided for @txnSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get txnSaveChanges;

  /// No description provided for @txnSaveTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save template'**
  String get txnSaveTemplate;

  /// No description provided for @txnSplitAction.
  ///
  /// In en, this message translates to:
  /// **'Split across categories'**
  String get txnSplitAction;

  /// No description provided for @txnRecentCategories.
  ///
  /// In en, this message translates to:
  /// **'Recent categories'**
  String get txnRecentCategories;

  /// No description provided for @txnFromAccount.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get txnFromAccount;

  /// No description provided for @txnToAccount.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get txnToAccount;

  /// No description provided for @txnChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose account'**
  String get txnChooseAccount;

  /// No description provided for @txnChooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose category'**
  String get txnChooseCategory;

  /// No description provided for @txnKeypad.
  ///
  /// In en, this message translates to:
  /// **'Amount keypad'**
  String get txnKeypad;

  /// No description provided for @txnDecimalSeparator.
  ///
  /// In en, this message translates to:
  /// **'Decimal separator'**
  String get txnDecimalSeparator;

  /// No description provided for @txnDeleteDigit.
  ///
  /// In en, this message translates to:
  /// **'Delete digit'**
  String get txnDeleteDigit;

  /// No description provided for @txnPlus.
  ///
  /// In en, this message translates to:
  /// **'Plus'**
  String get txnPlus;

  /// No description provided for @txnMinus.
  ///
  /// In en, this message translates to:
  /// **'Minus'**
  String get txnMinus;

  /// No description provided for @txnTimes.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get txnTimes;

  /// No description provided for @txnDivide.
  ///
  /// In en, this message translates to:
  /// **'Divided by'**
  String get txnDivide;

  /// No description provided for @txnAmountPreview.
  ///
  /// In en, this message translates to:
  /// **'= {amount}'**
  String txnAmountPreview(String amount);

  /// No description provided for @txnErrAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get txnErrAmount;

  /// No description provided for @txnErrAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'This calculation is not valid'**
  String get txnErrAmountInvalid;

  /// No description provided for @txnErrDivZero.
  ///
  /// In en, this message translates to:
  /// **'Division by zero'**
  String get txnErrDivZero;

  /// No description provided for @txnErrTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This amount is too large'**
  String get txnErrTooLarge;

  /// No description provided for @txnErrRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get txnErrRequired;

  /// No description provided for @txnErrSameAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose two different accounts'**
  String get txnErrSameAccount;

  /// No description provided for @txnErrSplit.
  ///
  /// In en, this message translates to:
  /// **'The split lines must add up to the total'**
  String get txnErrSplit;

  /// No description provided for @txnErrNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account first to record transactions.'**
  String get txnErrNoAccount;

  /// No description provided for @txnErrCheckFields.
  ///
  /// In en, this message translates to:
  /// **'Please check the highlighted fields.'**
  String get txnErrCheckFields;

  /// No description provided for @txnCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get txnCreateAccount;

  /// No description provided for @txnSavedExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense saved'**
  String get txnSavedExpense;

  /// No description provided for @txnSavedIncome.
  ///
  /// In en, this message translates to:
  /// **'Income saved'**
  String get txnSavedIncome;

  /// No description provided for @txnSavedTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer saved'**
  String get txnSavedTransfer;

  /// No description provided for @txnChangesSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get txnChangesSaved;

  /// No description provided for @txnSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {message}'**
  String txnSaveFailed(String message);

  /// No description provided for @txnAddSplit.
  ///
  /// In en, this message translates to:
  /// **'Add split'**
  String get txnAddSplit;

  /// No description provided for @txnRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining {amount}'**
  String txnRemaining(String amount);

  /// No description provided for @txnOverAssigned.
  ///
  /// In en, this message translates to:
  /// **'Over by {amount}'**
  String txnOverAssigned(String amount);

  /// No description provided for @txnFullyAssigned.
  ///
  /// In en, this message translates to:
  /// **'Fully assigned'**
  String get txnFullyAssigned;

  /// No description provided for @txnRemoveSplit.
  ///
  /// In en, this message translates to:
  /// **'Remove line'**
  String get txnRemoveSplit;

  /// No description provided for @txnSplitLineCategory.
  ///
  /// In en, this message translates to:
  /// **'Split {n} category'**
  String txnSplitLineCategory(int n);

  /// No description provided for @txnSplitLineAmount.
  ///
  /// In en, this message translates to:
  /// **'Split {n} amount'**
  String txnSplitLineAmount(int n);

  /// No description provided for @txnAssignRemaining.
  ///
  /// In en, this message translates to:
  /// **'Assign remaining'**
  String get txnAssignRemaining;

  /// No description provided for @txnStopSplit.
  ///
  /// In en, this message translates to:
  /// **'Remove split'**
  String get txnStopSplit;

  /// No description provided for @txnAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get txnAddTag;

  /// No description provided for @txnRemoveTag.
  ///
  /// In en, this message translates to:
  /// **'Remove tag {name}'**
  String txnRemoveTag(String name);

  /// No description provided for @txnCreateTag.
  ///
  /// In en, this message translates to:
  /// **'Create “{name}”'**
  String txnCreateTag(String name);

  /// No description provided for @txnSearchTags.
  ///
  /// In en, this message translates to:
  /// **'Search or create a tag'**
  String get txnSearchTags;

  /// No description provided for @txnMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get txnMoreDetails;

  /// No description provided for @txnUseTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use template {name}'**
  String txnUseTemplate(String name);

  /// No description provided for @txnTemplatesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No templates yet. Save a transaction as a template to enter it with one tap.'**
  String get txnTemplatesEmpty;

  /// No description provided for @txnTemplateAddNow.
  ///
  /// In en, this message translates to:
  /// **'Add now'**
  String get txnTemplateAddNow;

  /// No description provided for @txnTemplatePosted.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String txnTemplatePosted(String name);

  /// No description provided for @txnTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get txnTemplateName;

  /// No description provided for @txnTemplateDeleted.
  ///
  /// In en, this message translates to:
  /// **'Template deleted'**
  String get txnTemplateDeleted;

  /// No description provided for @txnTemplateFillIn.
  ///
  /// In en, this message translates to:
  /// **'Open in quick add'**
  String get txnTemplateFillIn;

  /// No description provided for @txnTemplateInvalid.
  ///
  /// In en, this message translates to:
  /// **'This template is incomplete. Edit it to choose an account.'**
  String get txnTemplateInvalid;

  /// No description provided for @txnPickDate.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get txnPickDate;

  /// No description provided for @txnClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get txnClear;

  /// No description provided for @txnSum.
  ///
  /// In en, this message translates to:
  /// **'Total {amount}'**
  String txnSum(String amount);

  /// No description provided for @txnKeyDelete.
  ///
  /// In en, this message translates to:
  /// **'Del'**
  String get txnKeyDelete;

  /// No description provided for @txnImportBatchChip.
  ///
  /// In en, this message translates to:
  /// **'From one import'**
  String get txnImportBatchChip;

  /// No description provided for @txnCreateRule.
  ///
  /// In en, this message translates to:
  /// **'Create rule'**
  String get txnCreateRule;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
