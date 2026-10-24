// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get accountsTitle => 'Konten';

  @override
  String get accountsAdd => 'Konto hinzufügen';

  @override
  String get accountsEmpty =>
      'Noch keine Konten. Füge Bankkonten, Bargeld und Karten hinzu, um Salden und Vermögen zu verfolgen.';

  @override
  String get accountsReorder => 'Konten sortieren';

  @override
  String get accountsReorderHint =>
      'Ziehe Konten, um die Reihenfolge zu ändern, oder unter eine andere Überschrift, um sie in diese Gruppe zu verschieben.';

  @override
  String accountsDragHandle(String name) {
    return '$name verschieben';
  }

  @override
  String get accountsReconcileBalances => 'Kontoabgleich';

  @override
  String get accountsSelectHint => 'Wähle ein Konto, um die Details zu sehen.';

  @override
  String get accountsMoreActions => 'Weitere Aktionen';

  @override
  String get accountsManageGroups => 'Gruppen verwalten';

  @override
  String get accountsShowArchivedMenu => 'Archivierte Konten zeigen';

  @override
  String get accountsHideArchived => 'Archivierte Konten ausblenden';

  @override
  String accountsShowArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivierte Konten zeigen',
      one: '1 archiviertes Konto zeigen',
    );
    return '$_temp0';
  }

  @override
  String get accountsArchivedSection => 'Archiviert';

  @override
  String get accountsArchivedDesc =>
      'In Listen und Auswahlen ausgeblendet. Der Verlauf bleibt erhalten.';

  @override
  String get accountsNetWorth => 'Vermögen';

  @override
  String get accountsAssets => 'Vermögenswerte';

  @override
  String get accountsLiabilities => 'Verbindlichkeiten';

  @override
  String accountsNetWorthSemantics(
    String net,
    String assets,
    String liabilities,
  ) {
    return 'Vermögen $net. Vermögenswerte $assets, Verbindlichkeiten $liabilities.';
  }

  @override
  String accountsAlertBelow(String amount) {
    return 'Warnung unter $amount';
  }

  @override
  String accountsBelowThreshold(String amount) {
    return 'Unter der Warnschwelle $amount';
  }

  @override
  String get accountsNotInNetWorth => 'Nicht im Vermögen';

  @override
  String get accountsNotInBudgets => 'Nicht in Budgets';

  @override
  String get accountsNotInForecast => 'Nicht in der Prognose';

  @override
  String accountsReturnAssumed(String rate) {
    return '$rate p. a. angenommen';
  }

  @override
  String accountsInterestRate(String rate) {
    return '$rate Zinsen';
  }

  @override
  String get accountsOpen => 'Öffnen';

  @override
  String get accountsReconcile => 'Abgleichen';

  @override
  String get accountsArchive => 'Archivieren';

  @override
  String get accountsUnarchive => 'Wiederherstellen';

  @override
  String get accountsNoGroup => 'Ohne Gruppe';

  @override
  String get accountsTypeChecking => 'Girokonto';

  @override
  String get accountsTypeSavings => 'Sparkonto';

  @override
  String get accountsTypeCash => 'Bargeld';

  @override
  String get accountsTypeCreditCard => 'Kreditkarte';

  @override
  String get accountsTypeInvestment => 'Depot';

  @override
  String get accountsTypeLoan => 'Kredit';

  @override
  String get accountsTypeOtherAsset => 'Sonstiges Vermögen';

  @override
  String get accountsTypeOtherLiability => 'Sonstige Verbindlichkeit';

  @override
  String get accountsArchivedSnack => 'Konto archiviert';

  @override
  String get accountsUnarchivedSnack => 'Konto wiederhergestellt';

  @override
  String get accountsCannotDeleteTitle => 'Konto wird verwendet';

  @override
  String accountsDeleteInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Dieses Konto hat $count Buchungen und kann nicht gelöscht werden. Archiviere es, um es auszublenden und den Verlauf zu behalten.',
      one: 'Dieses Konto hat 1 Buchung und kann nicht gelöscht werden. Archiviere es, um es auszublenden und den Verlauf zu behalten.',
    );
    return '$_temp0';
  }

  @override
  String accountsDeleteInUseRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Dauerbuchungen verwenden dieses Konto. Ändere oder lösche sie zuerst oder archiviere das Konto.',
      one: 'Eine Dauerbuchung verwendet dieses Konto. Ändere oder lösche sie zuerst oder archiviere das Konto.',
    );
    return '$_temp0';
  }

  @override
  String get accountsDeleteMessage =>
      'Das Konto hat keine Buchungen. Verknüpfte Sparziele werden gelöst.';

  @override
  String get accountsDeleted => 'Konto gelöscht';

  @override
  String get accountsNotFound => 'Dieses Konto existiert nicht mehr.';

  @override
  String get accountsRange1M => '1M';

  @override
  String get accountsRange3M => '3M';

  @override
  String get accountsRange6M => '6M';

  @override
  String get accountsRange1Y => '1J';

  @override
  String get accountsRangeAll => 'Alles';

  @override
  String get accountsCurrentBalance => 'Aktueller Saldo';

  @override
  String accountsLowBalanceWarning(String amount) {
    return 'Unter der Warnschwelle von $amount';
  }

  @override
  String get accountsBalanceOverTime => 'Saldoverlauf';

  @override
  String get accountsChartEmpty => 'Noch nicht genug Daten für ein Diagramm.';

  @override
  String accountsChartSemantics(
    String name,
    String from,
    String to,
    String start,
    String end,
    String lowest,
  ) {
    return 'Saldo von $name vom $from bis $to: $start zu Beginn, $end am Ende, Tiefstwert $lowest.';
  }

  @override
  String get accountsRecentTransactions => 'Letzte Buchungen';

  @override
  String get accountsAllTransactions => 'Alle';

  @override
  String get accountsNoTransactions => 'Noch keine Buchungen auf diesem Konto.';

  @override
  String get accountsDetails => 'Details';

  @override
  String accountsTransferWith(String name) {
    return 'Umbuchung · $name';
  }

  @override
  String get accountsSplit => 'Aufgeteilt';

  @override
  String get accountsUncategorized => 'Ohne Kategorie';

  @override
  String get accountsNew => 'Neues Konto';

  @override
  String get accountsEditTitle => 'Konto bearbeiten';

  @override
  String get accountsCreate => 'Konto anlegen';

  @override
  String get accountsSectionBasics => 'Grunddaten';

  @override
  String get accountsSectionAppearance => 'Darstellung';

  @override
  String get accountsSectionInclude => 'Zählt zu';

  @override
  String get accountsSectionPlanning => 'Planung';

  @override
  String get accountsFieldName => 'Name';

  @override
  String get accountsNameRequired => 'Gib einen Namen ein';

  @override
  String get accountsFieldType => 'Kontoart';

  @override
  String get accountsFieldOpeningBalance => 'Anfangssaldo';

  @override
  String get accountsFieldOpeningDate => 'Eröffnungsdatum';

  @override
  String get accountsLiabilityHint =>
      'Schulden als negativen Betrag eingeben, z. B. −4.152,30.';

  @override
  String get accountsFieldGroup => 'Gruppe';

  @override
  String get accountsNewGroup => 'Neue Gruppe …';

  @override
  String get accountsGroupName => 'Gruppenname';

  @override
  String get accountsIncludeNetWorth => 'Vermögen';

  @override
  String get accountsIncludeBudgets => 'Budgets';

  @override
  String get accountsIncludeBudgetsDesc =>
      'Ausgaben von diesem Konto zählen zu den Budgets';

  @override
  String get accountsIncludeForecast => 'Prognose';

  @override
  String get accountsLowBalance => 'Warnschwelle';

  @override
  String get accountsLowBalanceHint =>
      'Warnen, wenn der Saldo unter diesen Betrag fällt';

  @override
  String get accountsExpectedReturn => 'Erwartete Rendite p. a.';

  @override
  String get accountsExpectedReturnHint =>
      'Wird für die Vermögensprognose verwendet';

  @override
  String get accountsInterest => 'Zinssatz';

  @override
  String get accountsInterestHint =>
      'Jahreszins, z. B. für Kredite und Kreditkarten';

  @override
  String get accountsRateInvalid =>
      'Gib einen Prozentwert zwischen −100 und 100 ein';

  @override
  String get accountsNote => 'Notiz';

  @override
  String get accountsDiscardTitle => 'Änderungen verwerfen?';

  @override
  String get accountsKeepEditing => 'Weiter bearbeiten';

  @override
  String get accountsDiscard => 'Verwerfen';

  @override
  String get accountsReconcileTitle => 'Kontoabgleich';

  @override
  String get accountsReconcileIntro =>
      'Gib den Saldo ein, den deine Bank für das Datum unten anzeigt. Die gebuchten Umsätze in der App sollten ihn ergeben.';

  @override
  String get accountsBankBalance => 'Kontostand laut Bank';

  @override
  String get accountsBankDate => 'Stichtag';

  @override
  String get accountsDifference => 'Differenz';

  @override
  String get accountsClearedBalance => 'Gebucht in der App';

  @override
  String accountsPendingSum(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vorgemerkt ($count)',
      one: 'Vorgemerkt (1)',
      zero: 'Vorgemerkt',
    );
    return '$_temp0';
  }

  @override
  String get accountsEnterBankBalance =>
      'Gib den Kontostand der Bank zum Vergleich ein.';

  @override
  String get accountsReconciled =>
      'Ausgeglichen. Die App stimmt mit deiner Bank überein.';

  @override
  String get accountsDifferenceMore =>
      'Die Bank zeigt mehr als die App. Bestätige vorgemerkte Einnahmen oder ergänze fehlende Buchungen.';

  @override
  String get accountsDifferenceLess =>
      'Die Bank zeigt weniger als die App. Bestätige vorgemerkte Ausgaben, die die Bank schon gebucht hat.';

  @override
  String accountsCreateCorrection(String amount) {
    return 'Korrektur über $amount buchen';
  }

  @override
  String get accountsCreateCorrectionShort => 'Korrektur buchen';

  @override
  String get accountsCorrectionConfirmTitle => 'Korrektur buchen?';

  @override
  String accountsCorrectionConfirm(String amount) {
    return 'Eine gebuchte Transaktion über $amount wird hinzugefügt, damit die App zum Kontostand passt.';
  }

  @override
  String get accountsCorrectionPayee => 'Kontoabgleich';

  @override
  String get accountsCorrectionNote => 'Korrektur auf den Kontostand der Bank';

  @override
  String get accountsCorrectionCreated => 'Korrektur gebucht';

  @override
  String get accountsPendingTitle => 'Vorgemerkte Buchungen';

  @override
  String get accountsPendingHint =>
      'Wähle die aus, die deine Bank schon gebucht hat, und markiere sie als gebucht.';

  @override
  String get accountsNoPending =>
      'Keine vorgemerkten Buchungen bis zu diesem Datum.';

  @override
  String get accountsSelectAll => 'Alle auswählen';

  @override
  String get accountsMarkClearedNone => 'Als gebucht markieren';

  @override
  String accountsMarkCleared(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count als gebucht markieren ($amount)',
      one: '1 als gebucht markieren ($amount)',
    );
    return '$_temp0';
  }

  @override
  String accountsMarkedCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Buchungen bestätigt',
      one: '1 Buchung bestätigt',
    );
    return '$_temp0';
  }

  @override
  String get accountsGroupsTitle => 'Kontogruppen';

  @override
  String get accountsGroupsEmpty =>
      'Noch keine Gruppen. Gruppen bündeln Konten in der Liste, z. B. „Alltag“ oder „Sparen“.';

  @override
  String get accountsGroupsHint =>
      'Tippen zum Umbenennen, ziehen zum Sortieren. Beim Löschen einer Gruppe bleiben die Konten erhalten.';

  @override
  String get accountsGroupAdd => 'Gruppe hinzufügen';

  @override
  String get accountsGroupRename => 'Gruppe umbenennen';

  @override
  String get accountsGroupDeleteMessage =>
      'Die Konten bleiben erhalten und sind dann ohne Gruppe.';

  @override
  String get accountsGroupDeleted => 'Gruppe gelöscht';

  @override
  String accountsGroupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten',
      one: '1 Konto',
      zero: 'Keine Konten',
    );
    return '$_temp0';
  }

  @override
  String get backupBootTitle => 'Deine Daten konnten nicht geöffnet werden';

  @override
  String get backupBootMissingKey =>
      'Der Schlüssel, der die Datenbank entsperrt, fehlt auf diesem Gerät. Das passiert, wenn App-Daten ohne den sicheren Speicher des Geräts auf ein neues Gerät kopiert oder wiederhergestellt werden.';

  @override
  String get backupBootNewer =>
      'Die Datenbank wurde von einer neueren Version der App erstellt. Installiere die neueste Version, um sie zu öffnen.';

  @override
  String get backupBootGeneric =>
      'Die Datenbankdatei konnte nicht geöffnet werden.';

  @override
  String get backupBootKept =>
      'Es wurde nichts gelöscht. Die Datenbankdatei bleibt auf diesem Gerät.';

  @override
  String get backupBootDetails => 'Technische Details';

  @override
  String get backupBootStartFresh => 'Mit leerer Datenbank starten';

  @override
  String get backupBootStartFreshConfirm =>
      'Die aktuelle Datenbankdatei wird in einen eigenen Ordner verschoben, nicht gelöscht. Die App startet dann leer, und du kannst unter Mehr › Export & Sicherung eine Sicherung wiederherstellen.';

  @override
  String backupBootMoved(String path) {
    return 'Die alte Datenbankdatei wurde verschoben nach:\n$path';
  }

  @override
  String backupMissingReceipts(int count) {
    return 'Sicherung gespeichert. $count Belegdateien fehlten bereits auf diesem Gerät und sind nicht enthalten.';
  }

  @override
  String get backupReceipts => 'Belege';

  @override
  String backupReceiptsValue(int count, String size) {
    return '$count Dateien, $size';
  }

  @override
  String backupRestoreMissing(int count) {
    return '$count Belegdateien fehlten bereits beim Erstellen dieser Sicherung und können nicht wiederhergestellt werden.';
  }

  @override
  String get backupChannel => 'Sicherungen';

  @override
  String get backupHealthBackUp => 'Jetzt sichern';

  @override
  String get backupHealthDetails => 'Details';

  @override
  String backupHealthFailing(String message) {
    return 'Die automatische Sicherung ist fehlgeschlagen: $message';
  }

  @override
  String get backupHealthInterrupted =>
      'Die letzte automatische Sicherung wurde nicht abgeschlossen.';

  @override
  String get backupHealthNever => 'Deine Daten wurden noch nicht gesichert.';

  @override
  String backupHealthStale(String date) {
    return 'Letzte Sicherung: $date. Sichere erneut, damit auch neue Änderungen sicher sind.';
  }

  @override
  String get backupNotifyFailedTitle => 'Sicherung fehlgeschlagen';

  @override
  String get backupNotifyFailedBody =>
      'Deine automatische Sicherung konnte nicht geschrieben werden. Öffne die App, um das zu beheben.';

  @override
  String get backupResetKeepCopy =>
      'Sicherheitskopie auf diesem Gerät behalten';

  @override
  String get backupResetKeepCopyDesc =>
      'Damit lässt sich das Zurücksetzen unter Mehr › Export & Sicherung › Sicherheitskopien rückgängig machen. Abwählen, um auch die Sicherheitskopien zu löschen.';

  @override
  String get backupSafetyActions => 'Aktionen';

  @override
  String get backupSafetyDelete => 'Löschen';

  @override
  String backupSafetyDeleteConfirm(String date) {
    return 'Sicherheitskopie vom $date löschen?';
  }

  @override
  String get backupSafetyDesc =>
      'Werden automatisch erstellt vor dem Wiederherstellen, dem Zurücksetzen, dem Rückgängigmachen eines Imports, dem Zusammenführen von Kategorien oder Tags und dem Entfernen alter gelöschter Einträge. Sie bleiben auf diesem Gerät und enthalten alle Daten außer Belegdateien, die diese Aktionen nie löschen. Die neuesten 10 werden behalten.';

  @override
  String get backupSafetyEmpty => 'Noch keine Sicherheitskopien.';

  @override
  String backupSafetyFailed(String message) {
    return 'Es konnte keine Sicherheitskopie erstellt werden, deshalb wurde nichts geändert: $message';
  }

  @override
  String get backupSafetyReasonImportUndo =>
      'Vor dem Rückgängigmachen eines Imports';

  @override
  String get backupSafetyReasonMerge => 'Vor dem Zusammenführen';

  @override
  String get backupSafetyReasonPurge =>
      'Vor dem Entfernen alter gelöschter Einträge';

  @override
  String get backupSafetyReasonReset => 'Vor dem Zurücksetzen der App';

  @override
  String get backupSafetyReasonRestore =>
      'Vor dem Wiederherstellen einer Sicherung';

  @override
  String get backupSafetyReasonRestoreCopy =>
      'Vor dem Wiederherstellen einer Sicherheitskopie';

  @override
  String get backupSafetyRestore => 'Wiederherstellen';

  @override
  String backupSafetyRestoreConfirm(String date) {
    return 'Alle aktuellen Daten durch die Sicherheitskopie vom $date ersetzen? Vorher wird eine Sicherheitskopie der aktuellen Daten erstellt, damit du zurück kannst.';
  }

  @override
  String backupSafetyRestored(int count) {
    return 'Sicherheitskopie wiederhergestellt ($count Zeilen)';
  }

  @override
  String backupSafetyRows(String rows, String size) {
    return '$rows Zeilen · $size';
  }

  @override
  String get backupSafetySave => 'Woanders speichern';

  @override
  String get backupSafetyTitle => 'Sicherheitskopien';

  @override
  String get backupStaleDays =>
      'Warnen, wenn die letzte Sicherung älter ist als';

  @override
  String backupStaleDaysValue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get backupFolderAccessLost =>
      'Die App hat keinen Zugriff mehr auf den Sicherungsordner. Wähle den Ordner erneut aus.';

  @override
  String get backupUseAppDocuments =>
      '„Auf meinem iPhone“ in Dateien verwenden';

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String get budgetsBudgeted => 'Budgetiert';

  @override
  String get budgetsSpent => 'Ausgegeben';

  @override
  String get budgetsLeftLabel => 'Übrig';

  @override
  String budgetsLeftDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Übrig · $days Tage',
      one: 'Übrig · 1 Tag',
      zero: 'Übrig · letzter Tag',
    );
    return '$_temp0';
  }

  @override
  String budgetsTodayDayOf(int day, int total) {
    return 'Heute, Tag $day von $total';
  }

  @override
  String budgetsOfAmount(String amount) {
    return 'von $amount';
  }

  @override
  String budgetsOverBudget(String amount) {
    return '$amount über Budget';
  }

  @override
  String budgetsUsedLeft(int percent, String amount) {
    return '$percent % verbraucht · $amount übrig';
  }

  @override
  String budgetsAmountLeft(String amount) {
    return '$amount übrig';
  }

  @override
  String budgetsInclRolledOver(String amount) {
    return 'inkl. $amount übertragen';
  }

  @override
  String budgetsInclOverspentCarried(String amount) {
    return 'inkl. $amount Überzug übertragen';
  }

  @override
  String budgetsSpentOf(String spent, String available) {
    return '$spent von $available ausgegeben';
  }

  @override
  String budgetsUnbudgetedSpent(String amount) {
    return '$amount in Kategorien ohne Budget ausgegeben';
  }

  @override
  String get budgetsEmpty => 'Für diesen Zeitraum gibt es noch keine Budgets.';

  @override
  String get budgetsAdd => 'Budget hinzufügen';

  @override
  String get budgetsCopyPrevious => 'Vorherigen Zeitraum kopieren';

  @override
  String budgetsFromAverage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aus Durchschnitt von $count Zeiträumen',
      one: 'Aus Ausgaben des letzten Zeitraums',
    );
    return '$_temp0';
  }

  @override
  String get budgetsFromTemplate => 'Aus Vorlage';

  @override
  String get budgetsSaveTemplate => 'Als Vorlage speichern';

  @override
  String get budgetsEditAll => 'Alle Beträge bearbeiten';

  @override
  String get budgetsClearPeriod => 'Alle Budgets entfernen';

  @override
  String get budgetsClearPeriodTitle =>
      'Alle Budgets dieses Zeitraums entfernen?';

  @override
  String get budgetsClearPeriodMessage => 'Buchungen bleiben unverändert.';

  @override
  String get budgetsFillMenu => 'Befüllen';

  @override
  String budgetsFilledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Budgets gesetzt',
      one: '1 Budget gesetzt',
      zero: 'Keine Budgets gesetzt',
    );
    return '$_temp0';
  }

  @override
  String get budgetsNothingToCopy =>
      'Der vorherige Zeitraum hat keine Budgets.';

  @override
  String get budgetsNoSpendingHistory =>
      'In diesen Zeiträumen wurden keine Ausgaben gefunden.';

  @override
  String get budgetsOverwriteTitle => 'Vorhandene Beträge ersetzen?';

  @override
  String get budgetsOverwriteMessage =>
      'Kategorien mit einem Budget in diesem Zeitraum erhalten den neuen Betrag, alle anderen bleiben unverändert.';

  @override
  String get budgetsOverwriteConfirm => 'Ersetzen';

  @override
  String get budgetsAmountLabel => 'Budget';

  @override
  String get budgetsAmountInvalid => 'Gib einen Betrag ab 0 ein';

  @override
  String get budgetsRemove => 'Budget entfernen';

  @override
  String get budgetsTemplateName => 'Name der Vorlage';

  @override
  String get budgetsTemplateNameRequired => 'Gib einen Namen ein';

  @override
  String budgetsTemplateSaved(String name) {
    return 'Vorlage „$name“ gespeichert';
  }

  @override
  String budgetsTemplateSummary(int count, String total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Kategorien',
      one: '1 Kategorie',
    );
    return '$_temp0 · $total';
  }

  @override
  String get budgetsNoTemplates =>
      'Noch keine Vorlagen. Speichere zuerst einen Zeitraum als Vorlage.';

  @override
  String budgetsBulkTotal(String amount) {
    return 'Budgetiert gesamt: $amount';
  }

  @override
  String get budgetsNoCategories => 'Noch keine Ausgabenkategorien.';

  @override
  String budgetsLeftToAssign(String amount) {
    return '$amount noch zuzuweisen';
  }

  @override
  String get budgetsAllAssigned => 'Jeder Euro ist zugewiesen';

  @override
  String budgetsOverAssigned(String amount) {
    return '$amount mehr zugewiesen als verfügbar';
  }

  @override
  String budgetsEnvelopeFormula(String income, String carry, String assigned) {
    return 'Einnahmen $income + Übertrag $carry − zugewiesen $assigned';
  }

  @override
  String get budgetsSelectHint => 'Wähle ein Budget, um Details zu sehen.';

  @override
  String get budgetsCategoryMissing => 'Diese Kategorie existiert nicht mehr.';

  @override
  String get budgetsTransactionsInPeriod => 'Buchungen in diesem Zeitraum';

  @override
  String get budgetsNoTransactions => 'Keine Buchungen in diesem Zeitraum.';

  @override
  String get budgetsSpentNoBudget => 'ausgegeben · kein Budget festgelegt';

  @override
  String get budgetsBudgetedThisPeriod => 'In diesem Zeitraum budgetiert';

  @override
  String get budgetsCarriedIn => 'Aus dem letzten Zeitraum übertragen';

  @override
  String get budgetsRollsOverNext => 'Würde bei Zeitraumende übertragen';

  @override
  String get budgetsWarningAt => 'Warnung ab';

  @override
  String get budgetsEditAmount => 'Budget bearbeiten';

  @override
  String get budgetsSetBudget => 'Budget festlegen';

  @override
  String get budgetsRolloverOption => 'Übertrag';

  @override
  String get budgetsThresholdOption => 'Warnschwelle';

  @override
  String budgetsDefaultValue(String value) {
    return 'Standard ($value)';
  }

  @override
  String get budgetsHistory => 'Letzte Zeiträume';

  @override
  String budgetsHistoryRow(String period, String spent, String budget) {
    return '$period: $spent ausgegeben, Budget $budget';
  }

  @override
  String get budgetsHistoryLegend =>
      'Balken zeigen die Ausgaben, der Strich markiert das Budget.';

  @override
  String get budgetsSplitLine => 'Splitbuchung';

  @override
  String budgetsAlertOverTitle(String category) {
    return '$category liegt über dem Budget';
  }

  @override
  String budgetsAlertOverBody(String amount) {
    return '$amount über Budget in diesem Zeitraum.';
  }

  @override
  String budgetsAlertWarningTitle(String category) {
    return '$category ist fast aufgebraucht';
  }

  @override
  String budgetsAlertWarningBody(int percent, String amount) {
    return '$percent % verbraucht, $amount übrig.';
  }

  @override
  String budgetsAlertLowBalanceTitle(String account) {
    return 'Niedriger Kontostand: $account';
  }

  @override
  String budgetsAlertLowBalanceBody(String balance, String threshold) {
    return 'Kontostand $balance liegt unter $threshold.';
  }

  @override
  String get categoriesTitle => 'Kategorien';

  @override
  String get categoriesAdd => 'Kategorie hinzufügen';

  @override
  String get categoriesAddSub => 'Unterkategorie hinzufügen';

  @override
  String get categoriesNew => 'Neue Kategorie';

  @override
  String get categoriesNewSub => 'Neue Unterkategorie';

  @override
  String get categoriesEdit => 'Kategorie bearbeiten';

  @override
  String get categoriesName => 'Name';

  @override
  String get categoriesNameRequired => 'Gib einen Namen ein';

  @override
  String get categoriesParent => 'Oberkategorie';

  @override
  String get categoriesTopLevel => 'Keine (oberste Ebene)';

  @override
  String get categoriesParentLocked =>
      'Hat Unterkategorien und bleibt daher auf oberster Ebene';

  @override
  String get categoriesIcon => 'Symbol';

  @override
  String get categoriesPickIcon => 'Symbol wählen';

  @override
  String categoriesIconLabel(String name) {
    return 'Symbol $name';
  }

  @override
  String get categoriesColor => 'Farbe';

  @override
  String get categoriesColorNone => 'Standardfarbe';

  @override
  String categoriesColorLabel(int n) {
    return 'Farbe $n';
  }

  @override
  String get categoriesFavourite => 'Favorit';

  @override
  String get categoriesUnfavourite => 'Aus Favoriten entfernen';

  @override
  String get categoriesFavouriteDesc =>
      'Wird bei der Kategorieauswahl zuerst angezeigt';

  @override
  String get categoriesBudgetSection => 'Budget';

  @override
  String get categoriesRollover => 'Übertrag';

  @override
  String categoriesUseDefault(String value) {
    return 'Budget-Einstellung ($value)';
  }

  @override
  String get categoriesWarnThreshold => 'Warnschwelle';

  @override
  String get categoriesWarnThresholdHint =>
      'Leer lassen für die Budget-Einstellung';

  @override
  String get categoriesThresholdInvalid => 'Gib einen Wert von 1 bis 100 ein';

  @override
  String get categoriesArchived => 'Archiviert';

  @override
  String get categoriesArchivedDesc =>
      'In Auswahlen ausgeblendet; bestehende Buchungen behalten sie';

  @override
  String get categoriesArchive => 'Archivieren';

  @override
  String get categoriesUnarchive => 'Wiederherstellen';

  @override
  String get categoriesShowArchived => 'Archivierte zeigen';

  @override
  String get categoriesHideArchived => 'Archivierte ausblenden';

  @override
  String get categoriesMoreActions => 'Weitere Aktionen';

  @override
  String get categoriesReorder => 'Sortieren';

  @override
  String get categoriesReorderHint =>
      'Zum Sortieren ziehen. Unterkategorien sortierst du über ihre Oberkategorie.';

  @override
  String get categoriesReorderChildren => 'Unterkategorien sortieren';

  @override
  String categoriesSubCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Unterkategorien',
      one: '1 Unterkategorie',
    );
    return '$_temp0';
  }

  @override
  String categoriesUsage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Buchungen',
      one: '1 Buchung',
      zero: 'Noch nicht verwendet',
    );
    return '$_temp0';
  }

  @override
  String get categoriesEmpty =>
      'Noch keine Kategorien. Starte mit den Standardkategorien oder lege eigene an.';

  @override
  String get categoriesEmptyExpense => 'Noch keine Ausgabenkategorien.';

  @override
  String get categoriesEmptyIncome => 'Noch keine Einnahmenkategorien.';

  @override
  String get categoriesAddDefaults => 'Standardkategorien hinzufügen';

  @override
  String get categoriesMergeAction => 'Zusammenführen';

  @override
  String get categoriesMergeTitle => 'Zusammenführen?';

  @override
  String categoriesMergeConfirm(String source, String target) {
    return 'Alles aus „$source“ nach „$target“ verschieben? Buchungen, Aufteilungen, Budgets und Unterkategorien werden übernommen und „$source“ wird gelöscht.';
  }

  @override
  String categoriesMerged(String source, String target) {
    return '„$source“ in „$target“ zusammengeführt';
  }

  @override
  String get categoriesMergeInvalid =>
      'Wähle eine andere Kategorie derselben Art.';

  @override
  String get categoriesMergeNest =>
      'Eine Kategorie mit Unterkategorien kann nur in eine Kategorie der obersten Ebene zusammengeführt werden.';

  @override
  String get categoriesInvalidParent =>
      'Wähle eine Oberkategorie derselben Art.';

  @override
  String get categoriesHasChildrenError =>
      'Eine Kategorie mit Unterkategorien kann keine Unterkategorie werden.';

  @override
  String get categoriesInUseError => 'Diese Kategorie wird verwendet.';

  @override
  String get categoriesNotFound => 'Diese Kategorie existiert nicht mehr.';

  @override
  String get categoriesInUseTitle => 'Kategorie wird verwendet';

  @override
  String categoriesDeleteInUse(String name, int count, int budgets) {
    return '„$name“ wird von $count Buchungen und $budgets Budgets verwendet. Führe sie mit einer anderen Kategorie zusammen, um den Verlauf zu behalten, oder archiviere sie.';
  }

  @override
  String categoriesDeleteHasChildren(String name) {
    return 'Lösche oder verschiebe zuerst die Unterkategorien von „$name“.';
  }

  @override
  String get categoriesDeleted => 'Kategorie gelöscht';

  @override
  String categoriesModuleOff(String module) {
    return '$module ist ausgeschaltet. Schalte es unter Einstellungen › Navigation & Module ein.';
  }

  @override
  String get categoriesOpenSettings => 'Einstellungen öffnen';

  @override
  String get categoriesTagsTitle => 'Tags';

  @override
  String get categoriesTagAdd => 'Tag hinzufügen';

  @override
  String get categoriesTagNew => 'Neuer Tag';

  @override
  String get categoriesTagEdit => 'Tag bearbeiten';

  @override
  String get categoriesTagName => 'Tag-Name';

  @override
  String get categoriesTagTaken => 'Ein Tag mit diesem Namen gibt es schon';

  @override
  String get categoriesTagsEmpty =>
      'Noch keine Tags. Tags gelten kategorieübergreifend, z. B. #urlaub-2026 oder #erstattbar.';

  @override
  String categoriesTagMergeInto(String name) {
    return '#$name zusammenführen mit …';
  }

  @override
  String categoriesTagMergeConfirm(String source, String target) {
    return 'Alle Buchungen mit #$source nach #$target verschieben? #$source wird gelöscht; Buchungen mit beiden behalten einen Tag.';
  }

  @override
  String get categoriesTagNoMergeTarget =>
      'Es gibt keinen anderen Tag zum Zusammenführen.';

  @override
  String categoriesTagDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Er wird von $count Buchungen entfernt.',
      one: 'Er wird von 1 Buchung entfernt.',
    );
    return '$_temp0';
  }

  @override
  String get categoriesTagDeleted => 'Tag gelöscht';

  @override
  String get categoriesFieldsTitle => 'Eigene Felder';

  @override
  String get categoriesFieldAdd => 'Feld hinzufügen';

  @override
  String get categoriesFieldNew => 'Neues eigenes Feld';

  @override
  String get categoriesFieldEdit => 'Eigenes Feld bearbeiten';

  @override
  String get categoriesFieldName => 'Feldname';

  @override
  String get categoriesFieldType => 'Typ';

  @override
  String get categoriesFieldTypeText => 'Text';

  @override
  String get categoriesFieldTypeNumber => 'Zahl';

  @override
  String get categoriesFieldTypeDate => 'Datum';

  @override
  String get categoriesFieldTypeSelect => 'Einfachauswahl';

  @override
  String get categoriesFieldTypeMultiselect => 'Mehrfachauswahl';

  @override
  String get categoriesFieldTypeBoolean => 'Kontrollkästchen';

  @override
  String get categoriesFieldTypeLocked =>
      'Der Typ kann nicht geändert werden, weil schon Werte existieren.';

  @override
  String get categoriesFieldAppliesTo => 'Gilt für';

  @override
  String get categoriesFieldTransactions => 'Buchungen';

  @override
  String get categoriesFieldAccounts => 'Konten';

  @override
  String get categoriesFieldOptions => 'Optionen';

  @override
  String get categoriesFieldOptionHint => 'Neue Option';

  @override
  String get categoriesFieldAddOption => 'Option hinzufügen';

  @override
  String get categoriesFieldOptionsRequired =>
      'Füge mindestens eine Option hinzu';

  @override
  String categoriesFieldOptionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Optionen',
      one: '1 Option',
    );
    return '$_temp0';
  }

  @override
  String categoriesFieldValues(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Werte',
      one: '1 Wert',
      zero: 'Keine Werte',
    );
    return '$_temp0';
  }

  @override
  String get categoriesFieldArchivedDesc =>
      'Bei der Eingabe ausgeblendet; vorhandene Werte bleiben';

  @override
  String categoriesFieldDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Die $count gespeicherten Werte werden ebenfalls gelöscht.',
      one: 'Der 1 gespeicherte Wert wird ebenfalls gelöscht.',
    );
    return '$_temp0';
  }

  @override
  String get categoriesFieldDeleted => 'Eigenes Feld gelöscht';

  @override
  String get categoriesFieldsEmpty =>
      'Noch keine eigenen Felder. Füge Felder wie „Belegnr.“ oder „Projekt“ zu Buchungen oder Konten hinzu.';

  @override
  String get appTitle => 'Quiet Ledger';

  @override
  String get navHome => 'Start';

  @override
  String get navTransactions => 'Buchungen';

  @override
  String get navPlan => 'Planen';

  @override
  String get navForecast => 'Prognose';

  @override
  String get navMore => 'Mehr';

  @override
  String get navAccounts => 'Konten';

  @override
  String get navReports => 'Berichte';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get navImport => 'Import';

  @override
  String get navExport => 'Export';

  @override
  String get navRules => 'Regeln';

  @override
  String get navGoals => 'Sparziele';

  @override
  String get navScenarios => 'Szenarien';

  @override
  String get navCategories => 'Kategorien';

  @override
  String get navTags => 'Tags';

  @override
  String get addTransaction => 'Buchung hinzufügen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonNext => 'Weiter';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonUndo => 'Rückgängig';

  @override
  String get commonSearch => 'Suchen';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonNone => 'Keine';

  @override
  String get commonAll => 'Alle';

  @override
  String get commonReset => 'Zurücksetzen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonYes => 'Ja';

  @override
  String get commonNo => 'Nein';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonEmpty => 'Noch nichts vorhanden';

  @override
  String commonError(String message) {
    return 'Etwas ist schiefgelaufen: $message';
  }

  @override
  String commonDeleteConfirm(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get commonComingSoon => 'Dieser Bereich ist noch nicht verfügbar.';

  @override
  String get typeExpense => 'Ausgabe';

  @override
  String get typeIncome => 'Einnahme';

  @override
  String get typeTransfer => 'Umbuchung';

  @override
  String get statusCleared => 'Gebucht';

  @override
  String get statusPending => 'Ausstehend';

  @override
  String get statusPlanned => 'Geplant';

  @override
  String get privacyHiddenAmount => 'Verborgener Betrag, zum Anzeigen tippen';

  @override
  String get privacyToggle => 'Beträge verbergen';

  @override
  String get moreTemplates => 'Vorlagen';

  @override
  String get bootErrorTitle => 'Die Datenbank konnte nicht geöffnet werden';

  @override
  String get dashWidgetOptions => 'Widget-Optionen';

  @override
  String get dashNetWorth => 'Vermögen';

  @override
  String get dashThisMonth => 'diesen Monat';

  @override
  String dashAcrossAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten',
      one: '1 Konto',
    );
    return 'über $_temp0';
  }

  @override
  String dashIn12Months(String amount) {
    return '$amount in 12 Monaten';
  }

  @override
  String get dashNetWorthChart => 'Vermögen der letzten 12 Monate';

  @override
  String get dashLast12Months => 'Letzte 12 Monate';

  @override
  String dashSoFar(String month) {
    return '$month bisher';
  }

  @override
  String get dashExpenses => 'Ausgaben';

  @override
  String get dashSavingsRate => 'Sparquote';

  @override
  String get dashTopCategories => 'Top-Kategorien';

  @override
  String get dashNoSpending => 'Keine Ausgaben in diesem Zeitraum';

  @override
  String get dashUncategorised => 'Ohne Kategorie';

  @override
  String get dashAllAccounts => 'Alle Konten';

  @override
  String get dashViewAll => 'Alle anzeigen';

  @override
  String get dashBudgets => 'Budgets';

  @override
  String get dashAllBudgets => 'Alle Budgets';

  @override
  String get dashUpcoming => 'Anstehend';

  @override
  String dashNextDays(int days) {
    return 'nächste $days Tage';
  }

  @override
  String get dashCalendar => 'Kalender';

  @override
  String dashNoUpcoming(int days) {
    return 'In den nächsten $days Tagen ist nichts fällig';
  }

  @override
  String get dashGoals => 'Sparziele';

  @override
  String get dashNoGoals => 'Noch keine Sparziele';

  @override
  String get dashRecent => 'Letzte Buchungen';

  @override
  String get dashNoBudgets => 'Keine Budgets für diesen Zeitraum';

  @override
  String get dashSetUpBudgets => 'Budgets einrichten';

  @override
  String dashOver(String amount) {
    return '$amount drüber';
  }

  @override
  String dashOf(String amount) {
    return 'von $amount';
  }

  @override
  String get dashEdit => 'Dashboard bearbeiten';

  @override
  String get dashEditTitle => 'Dashboard bearbeiten';

  @override
  String get dashAddWidget => 'Widget hinzufügen';

  @override
  String get dashRemove => 'Entfernen';

  @override
  String get dashMakeWide => 'Breit anzeigen';

  @override
  String get dashMakeNormal => 'Normale Breite';

  @override
  String get dashChooseAccount => 'Konto wählen';

  @override
  String get dashResetLayout => 'Auf Standard zurücksetzen';

  @override
  String get dashLayoutPhone => 'Smartphone';

  @override
  String get dashLayoutWide => 'Tablet & Desktop';

  @override
  String get dashPrevPeriod => 'Vorheriger Zeitraum';

  @override
  String get dashNextPeriod => 'Nächster Zeitraum';

  @override
  String get dashToday => 'Zurück zu heute';

  @override
  String get dashSearchHint => 'Buchungen suchen';

  @override
  String get dashNewTransaction => 'Neue Buchung';

  @override
  String get dashAutoPost => 'automatisch';

  @override
  String get dashConfirm => 'bestätigen';

  @override
  String dashConfirmDaysBefore(int days) {
    return '$days Tage vorher bestätigen';
  }

  @override
  String get dashWelcomeEmpty =>
      'Erfasse deine erste Buchung, damit dein Dashboard lebendig wird.';

  @override
  String get dashWTypenetWorth => 'Vermögen';

  @override
  String get dashWTypemonthSummary => 'Monatsübersicht';

  @override
  String get dashWTypebudgets => 'Budgetfortschritt';

  @override
  String get dashWTypeupcomingBills => 'Anstehende Rechnungen';

  @override
  String get dashWTypeforecast => 'Mini-Prognose';

  @override
  String get dashWTypeaccounts => 'Konten';

  @override
  String get dashWTypegoals => 'Sparziel-Fortschritt';

  @override
  String get dashWTypetopCategories => 'Top-Kategorien';

  @override
  String get dashWTyperecentTransactions => 'Letzte Buchungen';

  @override
  String get exportTitle => 'Export & Sicherung';

  @override
  String get exportTxnTitle => 'Buchungen als CSV';

  @override
  String get exportTxnDesc =>
      'Buchungen eines Zeitraums und ausgewählter Konten exportieren, z. B. für Excel.';

  @override
  String get exportPeriod => 'Zeitraum';

  @override
  String get exportPeriodThisMonth => 'Dieser Monat';

  @override
  String get exportPeriodLastMonth => 'Letzter Monat';

  @override
  String get exportPeriodThisYear => 'Dieses Jahr';

  @override
  String get exportPeriodLastYear => 'Letztes Jahr';

  @override
  String get exportPeriodLast12Months => 'Letzte 12 Monate';

  @override
  String get exportPeriodAll => 'Gesamter Zeitraum';

  @override
  String get exportPeriodCustom => 'Benutzerdefiniert…';

  @override
  String exportPeriodRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get exportAccounts => 'Konten';

  @override
  String get exportAccountsAll => 'Alle Konten';

  @override
  String exportAccountsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten',
      one: '1 Konto',
    );
    return '$_temp0';
  }

  @override
  String get exportFiles => 'Dateien';

  @override
  String get exportLayoutFlat => 'Eine Datei';

  @override
  String get exportLayoutPerAccount => 'Je Konto eine';

  @override
  String get exportLayoutPerAccountHint =>
      'Wird gemeinsam als ZIP-Archiv gespeichert.';

  @override
  String get exportOptions => 'CSV-Optionen';

  @override
  String get exportOptionsEdit => 'Optionen bearbeiten';

  @override
  String get exportHeaderRow => 'Kopfzeile';

  @override
  String get exportColumns => 'Spalten';

  @override
  String exportColumnsSummary(int selected, int total) {
    return '$selected von $total Spalten';
  }

  @override
  String get exportColumnsHint => 'Ziehen, um die Reihenfolge zu ändern.';

  @override
  String get exportColumnsMin => 'Mindestens eine Spalte auswählen.';

  @override
  String get exportApply => 'Übernehmen';

  @override
  String get exportUseDefaults => 'Standard aus den Einstellungen';

  @override
  String get exportPresets => 'Vorlagen';

  @override
  String get exportPresetsEmpty => 'Noch keine gespeicherten Vorlagen.';

  @override
  String get exportPresetSave => 'Als Vorlage speichern';

  @override
  String get exportPresetName => 'Name der Vorlage';

  @override
  String exportPresetSaved(String name) {
    return 'Vorlage „$name“ gespeichert';
  }

  @override
  String exportPresetDeleted(String name) {
    return 'Vorlage „$name“ gelöscht';
  }

  @override
  String exportPresetApplied(String name) {
    return 'Vorlage „$name“ übernommen';
  }

  @override
  String exportPresetDelete(String name) {
    return 'Vorlage „$name“ löschen';
  }

  @override
  String get exportPreview => 'Vorschau';

  @override
  String exportPreviewHint(int count) {
    return 'erste $count Zeilen';
  }

  @override
  String get exportPreviewEmpty =>
      'Keine Buchungen im gewählten Zeitraum und in den gewählten Konten.';

  @override
  String get exportRun => 'CSV exportieren';

  @override
  String get exportRunZip => 'ZIP exportieren';

  @override
  String exportSaved(String location) {
    return 'Gespeichert unter $location';
  }

  @override
  String get exportSavedShort => 'Export gespeichert';

  @override
  String get exportShared => 'Export geteilt';

  @override
  String get exportDownloaded => 'Download gestartet';

  @override
  String exportRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen',
      one: '1 Zeile',
      zero: 'Keine Zeilen',
    );
    return '$_temp0';
  }

  @override
  String exportFailed(String message) {
    return 'Export fehlgeschlagen: $message';
  }

  @override
  String get exportWorking => 'Wird bearbeitet…';

  @override
  String get exportBackupTitle => 'Vollständige Sicherung';

  @override
  String get exportBackupDesc =>
      'Alle Daten und Einstellungen als ZIP mit CSV-Dateien und Prüfsummen. Zur Sicherung oder für den Umzug auf ein anderes Gerät.';

  @override
  String get exportBackupRun => 'Sicherung erstellen';

  @override
  String exportBackupDone(int count) {
    return 'Sicherung erstellt und geprüft ($count Zeilen)';
  }

  @override
  String get exportRestoreRun => 'Sicherung wiederherstellen…';

  @override
  String get exportRestoreTitle => 'Diese Sicherung wiederherstellen?';

  @override
  String get exportRestoreCreated => 'Erstellt';

  @override
  String get exportRestoreAppVersion => 'App-Version';

  @override
  String get exportRestoreDevice => 'Gerät';

  @override
  String get exportRestoreThisDevice => 'Dieses Gerät';

  @override
  String get exportRestoreOtherDevice => 'Anderes Gerät';

  @override
  String get exportRestoreTotalRows => 'Zeilen insgesamt';

  @override
  String get exportRestoreWarning =>
      'Alle Daten und Einstellungen auf diesem Gerät werden durch die Sicherung ersetzt. Vorher wird eine Sicherheitskopie der aktuellen Daten auf diesem Gerät behalten (Export & Sicherung › Sicherheitskopien).';

  @override
  String get exportRestoreBackupFirst =>
      'Zusätzlich eine Sicherung der aktuellen Daten woanders speichern';

  @override
  String get exportRestoreConfirm => 'Alle Daten ersetzen';

  @override
  String get exportRestoreAborted =>
      'Wiederherstellung abgebrochen. Es wurde nichts geändert.';

  @override
  String exportRestoreDone(int count) {
    return 'Sicherung wiederhergestellt ($count Zeilen)';
  }

  @override
  String exportRestoreFailed(String message) {
    return 'Wiederherstellung fehlgeschlagen, es wurde nichts geändert: $message';
  }

  @override
  String get exportErrTitle => 'Wiederherstellung nicht möglich';

  @override
  String get exportErrNotBundle =>
      'Diese Datei ist keine Sicherung dieser App.';

  @override
  String get exportErrNewerFormat =>
      'Diese Sicherung stammt von einer neueren App-Version. Aktualisiere die App, um sie wiederherzustellen.';

  @override
  String exportErrChecksum(String file) {
    return 'Die Sicherung ist beschädigt: $file stimmt nicht mit der Prüfsumme überein.';
  }

  @override
  String exportErrInvalid(String detail) {
    return 'Die Sicherung ist beschädigt: $detail';
  }

  @override
  String get exportAutoTitle => 'Automatische Sicherung';

  @override
  String get exportAutoDesc =>
      'Schreibt regelmäßig eine vollständige Sicherung in einen Ordner, z. B. einen, den ein Cloud-Client synchronisiert.';

  @override
  String get exportAutoSchedule => 'Zeitplan';

  @override
  String get exportAutoNoFolder => 'Kein Ordner gewählt';

  @override
  String get exportAutoChooseFolder => 'Ordner wählen…';

  @override
  String exportAutoLast(String date) {
    return 'Letzte Sicherung: $date';
  }

  @override
  String get exportAutoNever => 'Noch keine automatische Sicherung';

  @override
  String get exportAutoRunNow => 'Jetzt sichern';

  @override
  String exportAutoRunDone(String file) {
    return 'Sicherung geschrieben: $file';
  }

  @override
  String exportAutoRunFailed(String message) {
    return 'Sicherung fehlgeschlagen: $message';
  }

  @override
  String exportAutoKeepValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Neueste $count Sicherungen behalten',
      one: 'Neueste Sicherung behalten',
    );
    return '$_temp0';
  }

  @override
  String get exportAutoUnavailable =>
      'Automatische Sicherungen in einen Ordner sind im Browser nicht verfügbar. Nutze stattdessen „Sicherung erstellen“.';

  @override
  String get exportAutoNeedsFolder =>
      'Wähle einen Ordner, um automatische Sicherungen zu starten.';

  @override
  String get exportAutoSettings => 'Einstellungen der automatischen Sicherung';

  @override
  String get exportDecrease => 'Verringern';

  @override
  String get exportIncrease => 'Erhöhen';

  @override
  String get exportPurgeLast => 'Letzte Bereinigung gelöschter Einträge';

  @override
  String get exportColDate => 'Datum';

  @override
  String get exportColValueDate => 'Wertstellung';

  @override
  String get exportColAccount => 'Konto';

  @override
  String get exportColType => 'Art';

  @override
  String get exportColAmount => 'Betrag';

  @override
  String get exportColCurrency => 'Währung';

  @override
  String get exportColPayee => 'Empfänger';

  @override
  String get exportColNote => 'Notiz';

  @override
  String get exportColCategory => 'Kategorie';

  @override
  String get exportColSplit => 'Aufteilung';

  @override
  String get exportColTags => 'Tags';

  @override
  String get exportColStatus => 'Status';

  @override
  String get exportColTransferAccount => 'Gegenkonto';

  @override
  String get exportColId => 'ID';

  @override
  String get forecastTitle => 'Prognose';

  @override
  String get forecastTotal => 'Alle Konten';

  @override
  String get forecastChooseAccount => 'Konto wählen';

  @override
  String get forecastHorizon => 'Zeitraum';

  @override
  String forecastHorizonShort(int months) {
    return '$months Mon.';
  }

  @override
  String forecastHorizonLong(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months Monate',
      one: '1 Monat',
    );
    return '$_temp0';
  }

  @override
  String get forecastLowestPoint => 'Tiefster Stand';

  @override
  String forecastDaysBelow(int days, String limit) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage unter $limit',
      one: '1 Tag unter $limit',
    );
    return '$_temp0';
  }

  @override
  String forecastStaysAbove(Object limit) {
    return 'Bleibt über $limit';
  }

  @override
  String forecastLowestBelowThreshold(
    String amount,
    String date,
    String threshold,
  ) {
    return 'Tiefster Stand $amount am $date, unter deiner Schwelle von $threshold';
  }

  @override
  String forecastLowestBelowZero(String amount, String date) {
    return 'Tiefster Stand $amount am $date, unter null';
  }

  @override
  String forecastLowestOk(String amount, String date) {
    return 'Tiefster Stand $amount am $date';
  }

  @override
  String get forecastLegendBaseline => 'Basis';

  @override
  String get forecastLegendThreshold => 'Schwelle';

  @override
  String forecastChartSummary(
    String account,
    String start,
    String end,
    String amount,
    String date,
  ) {
    return 'Erwarteter täglicher Kontostand von $account vom $start bis $end. Tiefster Stand $amount am $date.';
  }

  @override
  String forecastChartThreshold(Object threshold) {
    return 'Mindestsaldo-Schwelle $threshold.';
  }

  @override
  String forecastChartScenario(String name, String amount, String date) {
    return 'Mit $name: tiefster Stand $amount am $date.';
  }

  @override
  String get forecastScenarios => 'Szenarien';

  @override
  String get forecastEditScenarios => 'Szenarien bearbeiten';

  @override
  String get forecastNoScenarios =>
      'Noch keine Szenarien. Probiere eine Gehaltserhöhung, eine große Anschaffung oder eine vorzeitige Kredittilgung aus.';

  @override
  String get forecastAddScenario => 'Szenario hinzufügen';

  @override
  String get forecastBalances => 'Kontostände';

  @override
  String get forecastMonths => 'Monate';

  @override
  String get forecastBudgetPeriods => 'Budgetzeiträume';

  @override
  String get forecastColMonth => 'Monat';

  @override
  String get forecastColPeriod => 'Zeitraum';

  @override
  String get forecastColLowest => 'Tiefster';

  @override
  String get forecastColEnd => 'Ende';

  @override
  String forecastColWith(Object name) {
    return 'Mit $name';
  }

  @override
  String forecastPartial(Object date) {
    return 'bis $date';
  }

  @override
  String get forecastWhatIf => 'Kann ich mir das leisten?';

  @override
  String get forecastWhatIfAmount => 'Betrag';

  @override
  String get forecastWhatIfDate => 'Datum';

  @override
  String get forecastWhatIfAccount => 'Von Konto';

  @override
  String get forecastWhatIfCheck => 'Prüfen';

  @override
  String get forecastWhatIfHint =>
      'Prüft nur die Prognose. Es wird nichts gespeichert.';

  @override
  String forecastWhatIfQuestion(String amount, String date, String account) {
    return 'Kann ich mir $amount am $date von $account leisten?';
  }

  @override
  String forecastWhatIfYes(String amount, String date) {
    return 'Ja. Danach liegt dein tiefster Stand bei $amount am $date.';
  }

  @override
  String forecastWhatIfTight(String amount, String date, String threshold) {
    return 'Knapp. Dein Kontostand fiele am $date auf $amount, unter deine Schwelle von $threshold.';
  }

  @override
  String forecastWhatIfNo(String amount, String date) {
    return 'Nein. Dein Kontostand fiele am $date auf $amount.';
  }

  @override
  String forecastWhatIfChange(Object delta) {
    return '$delta gegenüber jetzt';
  }

  @override
  String get forecastWhatIfEnterAmount => 'Betrag eingeben';

  @override
  String get forecastUpcoming => 'Anstehende große Posten';

  @override
  String get forecastNoEvents => 'Keine großen Posten in diesem Zeitraum.';

  @override
  String get forecastShowAll => 'Alle anzeigen';

  @override
  String get forecastShowLess => 'Weniger anzeigen';

  @override
  String get forecastWarnings => 'Warnungen';

  @override
  String forecastWarnBelowZero(String account, String date) {
    return '$account rutscht am $date unter null';
  }

  @override
  String forecastWarnBelowThreshold(
    String account,
    String threshold,
    String date,
  ) {
    return '$account fällt am $date unter $threshold';
  }

  @override
  String get forecastNoWarnings => 'Kein Konto fällt unter seine Schwelle.';

  @override
  String get forecastNoAccounts =>
      'Noch keine Konten in der Prognose. Lege ein Konto an oder aktiviere „In Prognose einbeziehen“.';

  @override
  String get forecastAddAccount => 'Konto anlegen';

  @override
  String get forecastModuleOff =>
      'Die Prognose ist ausgeschaltet. Du kannst sie unter Einstellungen › Navigation & Module einschalten.';

  @override
  String get forecastOpenSettings => 'Einstellungen öffnen';

  @override
  String get forecastProjection => 'Langfristige Projektion';

  @override
  String get forecastEventRecurring => 'Wiederkehrend';

  @override
  String get forecastEventScheduled => 'Geplant';

  @override
  String get forecastEventGoal => 'Sparziel-Beitrag';

  @override
  String get forecastEventOneOff => 'Szenario';

  @override
  String get forecastEventWhatIf => 'Was-wäre-wenn';

  @override
  String forecastTransferTo(Object account) {
    return 'An $account';
  }

  @override
  String forecastTransferFrom(Object account) {
    return 'Von $account';
  }

  @override
  String forecastVariableNote(Object method) {
    return 'Enthält erwartete variable Ausgaben: $method.';
  }

  @override
  String get forecastLoading => 'Prognose wird berechnet …';

  @override
  String get forecastProjYears => 'Jahre';

  @override
  String forecastProjYearsValue(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years Jahre',
      one: '1 Jahr',
    );
    return '$_temp0';
  }

  @override
  String get forecastProjSource => 'Sparbetrag aus';

  @override
  String get forecastProjSourceHistory => 'Verlauf';

  @override
  String get forecastProjSourcePlan => 'Plan';

  @override
  String forecastProjSourceHistoryDesc(Object amount) {
    return 'Durchschnitt der letzten 12 Monate: $amount pro Monat';
  }

  @override
  String forecastProjSourcePlanDesc(Object amount) {
    return 'Wiederkehrende Posten und erwartete Ausgaben: $amount im ersten Monat';
  }

  @override
  String get forecastProjRealDesc => 'In heutigem Geld (inflationsbereinigt)';

  @override
  String forecastProjPerYear(Object value) {
    return '$value pro Jahr';
  }

  @override
  String forecastProjNetWorthOn(Object date) {
    return 'Vermögen am $date';
  }

  @override
  String forecastProjToday(Object amount) {
    return 'Heute: $amount';
  }

  @override
  String get forecastProjMilestones => 'Meilensteine';

  @override
  String get forecastProjNoMilestones =>
      'Keine Meilensteine in diesem Zeitraum.';

  @override
  String forecastMilestoneNetWorth(Object amount) {
    return 'Vermögen erreicht $amount';
  }

  @override
  String get forecastMilestoneDebtFree => 'Schuldenfrei';

  @override
  String forecastMilestonePaidOff(Object account) {
    return '$account abbezahlt';
  }

  @override
  String forecastMilestoneGoal(Object goal) {
    return 'Sparziel erreicht: $goal';
  }

  @override
  String forecastProjChartSummary(
    String start,
    String end,
    String startAmount,
    String endAmount,
  ) {
    return 'Erwartetes Vermögen vom $start bis $end: heute $startAmount, am Ende $endAmount.';
  }

  @override
  String forecastProjChartMilestones(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Meilensteine.',
      one: '1 Meilenstein.',
      zero: 'Keine Meilensteine.',
    );
    return '$_temp0';
  }

  @override
  String get forecastProjAssumptions => 'Annahmen';

  @override
  String get forecastProjAssets => 'Vermögenswerte';

  @override
  String get forecastProjDebts => 'Schulden';

  @override
  String get forecastProjNominal => 'Nominal';

  @override
  String get forecastProjReal => 'Real';

  @override
  String get forecastProjNoAccounts =>
      'Noch keine Konten im Vermögen enthalten.';

  @override
  String get goalsNew => 'Neues Ziel';

  @override
  String get goalsEdit => 'Ziel bearbeiten';

  @override
  String get goalsEmpty =>
      'Noch keine Sparziele. Lege eines an, um zu sehen, wie viel du pro Zeitraum zurücklegen musst.';

  @override
  String get goalsNoActive => 'Alle Ziele sind archiviert.';

  @override
  String get goalsByPriority => 'Nach Priorität · zum Sortieren ziehen';

  @override
  String goalsArchived(int count) {
    return 'Archiviert ($count)';
  }

  @override
  String get goalsShow => 'Anzeigen';

  @override
  String get goalsHide => 'Ausblenden';

  @override
  String get goalsSelectHint => 'Wähle ein Ziel, um Details zu sehen.';

  @override
  String get goalsReached => 'Ziel erreicht';

  @override
  String goalsRequiredPerPeriod(String amount, String date) {
    return 'Benötigt $amount pro Zeitraum bis $date';
  }

  @override
  String goalsProjected(String date) {
    return 'Bei diesem Tempo: $date';
  }

  @override
  String get goalsNoPace =>
      'Lege einen geplanten Beitrag fest, um zu sehen, wann du es schaffst.';

  @override
  String get goalsOnTrack => 'Im Plan';

  @override
  String get goalsBehind => 'Im Verzug';

  @override
  String goalsOfTarget(String amount) {
    return 'von $amount';
  }

  @override
  String get goalsAddContribution => 'Beitrag hinzufügen';

  @override
  String get goalsReorder => 'Ziehen, um die Priorität zu ändern';

  @override
  String goalsSemanticProgress(String saved, String target) {
    return '$saved von $target gespart';
  }

  @override
  String get goalsDeposit => 'Einzahlen';

  @override
  String get goalsWithdraw => 'Entnehmen';

  @override
  String get goalsAmountInvalid => 'Gib einen Betrag ein';

  @override
  String get goalsModuleOff =>
      'Ziele sind unter Einstellungen › Navigation & Module ausgeschaltet.';

  @override
  String get goalsNotFound => 'Dieses Ziel existiert nicht mehr.';

  @override
  String get goalsSaved => 'Ziel gespeichert';

  @override
  String get goalsDetails => 'Ziel';

  @override
  String get goalsName => 'Name';

  @override
  String get goalsNameRequired => 'Gib einen Namen ein';

  @override
  String get goalsTarget => 'Zielbetrag';

  @override
  String get goalsTargetRequired => 'Gib einen Zielbetrag über 0 ein';

  @override
  String get goalsTargetDate => 'Zieldatum';

  @override
  String get goalsNoTargetDate => 'Kein Datum';

  @override
  String get goalsLinkedAccount => 'Verknüpftes Konto';

  @override
  String get goalsNoAccount => 'Keins – manuell verfolgen';

  @override
  String get goalsLinkedHelp =>
      'Der Fortschritt folgt dem Kontostand, das Tempo ergibt sich aus den letzten 3–6 Monaten.';

  @override
  String get goalsSavedSoFar => 'Bisher gespart';

  @override
  String get goalsPlannedContribution => 'Geplanter Beitrag pro Zeitraum';

  @override
  String get goalsPlannedContributionHelp =>
      'Wird für das voraussichtliche Datum genutzt, wenn kein Kontoverlauf vorhanden ist.';

  @override
  String get goalsArchive => 'Archivieren';

  @override
  String get goalsUnarchive => 'Wiederherstellen';

  @override
  String get importTitle => 'Import';

  @override
  String importStepOf(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String get importStepSource => 'Quelle';

  @override
  String get importStepSheets => 'Blätter';

  @override
  String get importStepStructure => 'Aufbau';

  @override
  String get importStepMapping => 'Spalten zuordnen';

  @override
  String get importStepFormats => 'Formate';

  @override
  String get importStepValues => 'Kategorien & Konten';

  @override
  String get importStepTransfers => 'Umbuchungen';

  @override
  String get importStepDuplicates => 'Duplikate';

  @override
  String get importStepSummary => 'Zusammenfassung';

  @override
  String importNextStep(String step) {
    return 'Weiter: $step';
  }

  @override
  String importProfileLabel(String name) {
    return 'Profil: $name';
  }

  @override
  String get importWorking => 'Wird verarbeitet …';

  @override
  String get importHistory => 'Import-Verlauf';

  @override
  String get importCancelTitle => 'Import verlassen?';

  @override
  String get importCancelMessage =>
      'Deine Einstellungen für diesen Import gehen verloren.';

  @override
  String get importCancelConfirm => 'Verlassen';

  @override
  String get importSourceIntro =>
      'Importiere deine Tabellen-Historie oder Bankexporte. Mehrere Dateien lassen sich in einem Durchgang importieren.';

  @override
  String get importPickFiles => 'Dateien wählen';

  @override
  String get importPickFilesHint => 'Excel (.xlsx, .xlsm, .xls), CSV oder TSV';

  @override
  String get importPasteTitle => 'Aus einer Tabelle einfügen';

  @override
  String get importPasteHint =>
      'Zeilen in Excel markieren, kopieren und hier einfügen.';

  @override
  String get importPasteButton => 'Aus Zwischenablage einfügen';

  @override
  String get importPasteAdd => 'Diese Zeilen verwenden';

  @override
  String get importPasteField => 'Eingefügte Zeilen';

  @override
  String get importPasteEmpty => 'Die Zwischenablage enthält keinen Text.';

  @override
  String get importFilesTitle => 'Dateien in diesem Import';

  @override
  String importFileSheets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Blätter',
      one: '1 Blatt',
    );
    return '$_temp0';
  }

  @override
  String importRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen',
      one: '1 Zeile',
    );
    return '$_temp0';
  }

  @override
  String importFileCsvInfo(String encoding, String delimiter) {
    return '$encoding · Trennzeichen $delimiter';
  }

  @override
  String get importRemoveFile => 'Entfernen';

  @override
  String get importCsvOptions => 'Leseoptionen';

  @override
  String get importEncoding => 'Zeichenkodierung';

  @override
  String get importAuto => 'Automatisch';

  @override
  String get importDelimiter => 'Trennzeichen';

  @override
  String get importQuote => 'Anführungszeichen';

  @override
  String get importTab => 'Tabulator';

  @override
  String get importErrOds =>
      'OpenDocument-Tabellen (.ods) können nicht gelesen werden. Öffne die Datei in LibreOffice Calc oder Excel, speichere sie als Excel-Arbeitsmappe (.xlsx) und importiere diese Datei.';

  @override
  String get importErrNumbers =>
      'Apple-Numbers-Dateien können nicht gelesen werden. Wähle in Numbers Ablage › Exportieren › Excel und importiere die .xlsx-Datei.';

  @override
  String get importErrEncrypted =>
      'Diese Arbeitsmappe ist kennwortgeschützt. Entferne das Kennwort in Excel (Datei › Informationen › Arbeitsmappe schützen), speichere sie und versuche es erneut.';

  @override
  String get importErrNotSpreadsheet =>
      'Diese Datei enthält keine importierbare Tabelle.';

  @override
  String get importErrCorrupt =>
      'Die Datei konnte nicht gelesen werden. Sie ist vielleicht beschädigt oder in einem nicht unterstützten Format.';

  @override
  String get importErrEmpty => 'Die Datei ist leer.';

  @override
  String get importProfileUse => 'Profil';

  @override
  String get importProfileNone => 'Kein Profil – alles erkennen';

  @override
  String get importProfileLoadFile => 'Profildatei laden';

  @override
  String get importProfileInvalid => 'Diese Datei ist kein Import-Profil.';

  @override
  String get importProfileHint =>
      'Ein Profil wiederholt alle Einstellungen eines früheren Imports.';

  @override
  String get importSheetsIntro =>
      'Wähle die zu importierenden Blätter und woher ihr Konto kommt.';

  @override
  String get importSheetHidden => 'ausgeblendet';

  @override
  String get importSheetNoData => 'Keine Buchungen gefunden';

  @override
  String get importAccountSource => 'Konto';

  @override
  String get importAccountFixed => 'Ein Konto';

  @override
  String get importAccountColumn => 'Aus einer Spalte';

  @override
  String get importAccountSheetName => 'Blattname';

  @override
  String get importAccountName => 'Kontoname';

  @override
  String get importAccountNameHint => 'Bestehendes oder neues Konto';

  @override
  String get importYear => 'Jahr für Daten ohne Jahr';

  @override
  String get importYearNone => 'Keins';

  @override
  String get importStructureIntro =>
      'Zeilen über der Kopfzeile (Titel, Bankangaben), Summenzeilen und leere Zeilen werden übersprungen.';

  @override
  String get importHeaderRow => 'Kopfzeile';

  @override
  String get importHeaderRows => 'Kopfzeilen';

  @override
  String get importNoHeader => 'Keine Kopfzeile';

  @override
  String get importFirstDataRow => 'Erste Datenzeile';

  @override
  String get importLastDataRow => 'Letzte Datenzeile';

  @override
  String get importUntilEnd => 'Bis zum Ende';

  @override
  String get importRowFilters => 'Zeilenfilter';

  @override
  String get importSkipPatterns =>
      'Summenzeilen überspringen, die beginnen mit';

  @override
  String get importSkipPatternsHint =>
      'Mit Kommas trennen; /…/ ist ein regulärer Ausdruck';

  @override
  String get importSkipWithoutDate => 'Zeilen ohne Datum überspringen';

  @override
  String get importSkipZero => 'Zeilen ohne Betrag überspringen';

  @override
  String get importRowData => 'Daten';

  @override
  String get importRowTitle => 'Titel';

  @override
  String get importRowHeader => 'Kopf';

  @override
  String get importRowEmpty => 'Leer';

  @override
  String get importRowSubtotal => 'Summenzeile';

  @override
  String get importRowNoDate => 'Kein Datum';

  @override
  String get importRowNoAmount => 'Kein Betrag';

  @override
  String get importRowAfterEnd => 'Nach dem Ende';

  @override
  String get importRowInvalid => 'Unlesbar';

  @override
  String importRowStats(int data, int skipped) {
    return '$data Datenzeilen · $skipped übersprungen';
  }

  @override
  String importPreviewMore(int shown, int total) {
    return 'Die ersten $shown von $total Zeilen';
  }

  @override
  String get importSheetPicker => 'Blatt';

  @override
  String importSheetInfo(String file, String sheet) {
    return '$file · Blatt „$sheet“';
  }

  @override
  String importInfoHeaderRow(int row) {
    return 'Kopfzeile in Zeile $row';
  }

  @override
  String get importInfoNoHeader => 'keine Kopfzeile';

  @override
  String importInfoSubtotals(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Summenzeilen übersprungen',
      one: '1 Summenzeile übersprungen',
    );
    return '$_temp0';
  }

  @override
  String get importAmountMode => 'Beträge stehen als';

  @override
  String get importAmountSigned => 'Mit Vorzeichen';

  @override
  String get importAmountDebitCredit => 'Aus + Ein';

  @override
  String get importAmountWithType => '+ Typspalte';

  @override
  String get importInvertSign => 'Ausgaben stehen als positive Zahlen';

  @override
  String get importTypeNegative => 'Typwerte für Ausgang';

  @override
  String get importTypePositive => 'Typwerte für Eingang';

  @override
  String get importCategorySeparator => 'Kategorie-Trennzeichen';

  @override
  String get importTagSeparator => 'Tag-Trennzeichen';

  @override
  String get importSeparatorNone => 'Keins';

  @override
  String get importSeparatorSpace => 'Leerzeichen';

  @override
  String get importTargetIgnore => 'Ignorieren';

  @override
  String get importTargetDate => 'Datum';

  @override
  String get importTargetValueDate => 'Wertstellung';

  @override
  String get importTargetAmount => 'Betrag';

  @override
  String get importTargetAmountAbs => 'Betrag (ohne Vorzeichen)';

  @override
  String get importTargetDebit => 'Betrag Ausgang (Soll)';

  @override
  String get importTargetCredit => 'Betrag Eingang (Haben)';

  @override
  String get importTargetAmountType => 'Typ (Ein/Aus)';

  @override
  String get importTargetPayee => 'Empfänger';

  @override
  String get importTargetNote => 'Beschreibung / Notiz';

  @override
  String get importTargetCategory => 'Kategorie';

  @override
  String importTargetCategorySub(String separator) {
    return 'Kategorie › Unter („$separator“)';
  }

  @override
  String get importTargetSubcategory => 'Unterkategorie';

  @override
  String get importTargetAccount => 'Konto';

  @override
  String get importTargetTags => 'Tags';

  @override
  String get importTargetStatus => 'Status';

  @override
  String importTargetCustom(String name) {
    return 'Eigenes Feld: $name';
  }

  @override
  String get importTargetBalance => 'Kontostand (Prüfung)';

  @override
  String importColumn(String letter) {
    return 'Spalte $letter';
  }

  @override
  String importBalanceCheck(int matched, int checked, String column) {
    return 'Saldenprüfung: $matched von $checked Zeilen stimmen mit Spalte $column überein';
  }

  @override
  String importBadValues(int count, String rows) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Werte nicht lesbar',
      one: '1 Wert nicht lesbar',
    );
    return '$_temp0 (Zeilen $rows)';
  }

  @override
  String importMismatches(int count, String rows) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Saldo-Abweichungen',
      one: '1 Saldo-Abweichung',
    );
    return '$_temp0 (Zeilen $rows)';
  }

  @override
  String get importApplyToSimilar =>
      'Für alle Blätter mit diesen Spalten verwenden';

  @override
  String importAppliedToSimilar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Auf $count weitere Blätter angewendet',
      one: 'Auf 1 weiteres Blatt angewendet',
      zero: 'Kein anderes Blatt hat diese Spalten',
    );
    return '$_temp0';
  }

  @override
  String get importNeedDateAmount =>
      'Ordne in jedem Blatt eine Datums- und eine Betragsspalte zu, um fortzufahren.';

  @override
  String importInvalidCell(String value) {
    return 'Nicht lesbar: $value';
  }

  @override
  String get importFormatsIntro =>
      'Formate werden je Spalte erkannt. Ändere sie, wenn Werte falsch gelesen werden.';

  @override
  String get importDateFormat => 'Datumsformat';

  @override
  String get importNumberFormat => 'Zahlenformat';

  @override
  String importDetected(String format) {
    return 'Erkannt: $format';
  }

  @override
  String get importDateSerial => 'Excel-Seriennummer (45000)';

  @override
  String get importDateDmy => 'Tag zuerst (31.12.2024)';

  @override
  String get importDateMdy => 'Monat zuerst (12/31/2024)';

  @override
  String get importDateYmd => 'ISO (2024-12-31)';

  @override
  String get importDateCompact => 'Kompakt (20241231)';

  @override
  String get importDateMonthName => 'Monatsname (31. Dez. 2024)';

  @override
  String get importDateCells => 'Datumszellen';

  @override
  String get importNumberDe => '1.234,56';

  @override
  String get importNumberEn => '1,234.56';

  @override
  String get importNumberSpace => '1 234,56';

  @override
  String get importSamples => 'Beispiele';

  @override
  String get importIssuesTitle => 'Nicht lesbare Werte';

  @override
  String get importNoIssues => 'Alle Werte sind lesbar.';

  @override
  String importIssueAt(int row, String column) {
    return 'Zeile $row, Spalte $column';
  }

  @override
  String get importIssueBadDate => 'Kein Datum';

  @override
  String get importIssueMissingDate => 'Datum fehlt';

  @override
  String get importIssueBadValueDate => 'Wertstellung nicht lesbar (ignoriert)';

  @override
  String get importIssueBadAmount => 'Kein Betrag';

  @override
  String get importIssueMissingAmount => 'Betrag fehlt';

  @override
  String get importIssueBadType => 'Unbekannter Typwert';

  @override
  String get importIssueBadBalance => 'Kontostand nicht lesbar (nicht geprüft)';

  @override
  String get importIssueBadStatus => 'Unbekannter Status (ignoriert)';

  @override
  String get importIssueBadCustomField => 'Wert des eigenen Felds nicht lesbar';

  @override
  String get importIssueMissingAccount => 'Kein Konto';

  @override
  String get importIssueYearMismatch => 'Datum außerhalb des Blattjahres';

  @override
  String importMoreIssues(int count) {
    return 'und $count weitere';
  }

  @override
  String get importAccountsTitle => 'Konten';

  @override
  String get importCategoriesTitle => 'Kategorien';

  @override
  String get importValuesIntro =>
      'Jeder Wert aus den Blättern wird einem bestehenden Eintrag zugeordnet oder neu angelegt.';

  @override
  String importValueRows(int count, String sum) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen',
      one: '1 Zeile',
    );
    return '$_temp0 · $sum';
  }

  @override
  String get importExisting => 'Bestehend';

  @override
  String get importCreateNew => 'Neu anlegen';

  @override
  String get importNoCategory => 'Keine Kategorie';

  @override
  String get importAsTransfer => 'Umbuchung';

  @override
  String get importTransferTo => 'Umbuchung auf Konto';

  @override
  String importNewAccountName(String name) {
    return 'Neues Konto „$name“';
  }

  @override
  String importNewCategoryName(String name) {
    return 'Neue Kategorie „$name“';
  }

  @override
  String get importChoose => 'Auswählen …';

  @override
  String importSuggestion(String name) {
    return 'Vorschlag: $name';
  }

  @override
  String get importAccountType => 'Kontoart';

  @override
  String get importCategoryKind => 'Art';

  @override
  String get importNoCategoryColumn =>
      'Die Blätter haben keine Kategoriespalte. Regeln und die Buchungsliste können später kategorisieren.';

  @override
  String get importAccTypeChecking => 'Girokonto';

  @override
  String get importAccTypeSavings => 'Sparkonto';

  @override
  String get importAccTypeCash => 'Bargeld';

  @override
  String get importAccTypeCreditCard => 'Kreditkarte';

  @override
  String get importAccTypeInvestment => 'Depot';

  @override
  String get importAccTypeLoan => 'Kredit';

  @override
  String get importAccTypeOtherAsset => 'Sonstiges Vermögen';

  @override
  String get importAccTypeOtherLiability => 'Sonstige Verbindlichkeit';

  @override
  String get importTransfersIntro =>
      'Geld, das ein Konto verlassen hat und auf einem anderen angekommen ist, wird zu einer Umbuchung zusammengeführt.';

  @override
  String get importDetectTransfers => 'Umbuchungen erkennen';

  @override
  String get importTransferWindow => 'Höchstens Tage auseinander';

  @override
  String importDaysApart(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage auseinander',
      one: '1 Tag auseinander',
      zero: 'selber Tag',
    );
    return '$_temp0';
  }

  @override
  String get importTransfersNone => 'Keine passenden Paare gefunden.';

  @override
  String importTransfersCount(int selected, int total) {
    return '$selected von $total Paaren zusammengeführt';
  }

  @override
  String get importMergeAll => 'Alle zusammenführen';

  @override
  String get importMergeNone => 'Keine zusammenführen';

  @override
  String get importDuplicatesIntro =>
      'Zeilen mit gleichem Datum, Betrag und Empfänger/Notiz wie eine bestehende Buchung werden übersprungen, außer du nimmst sie auf.';

  @override
  String get importIncremental =>
      'Nur Zeilen importieren, die seit dem letzten Import dieser Datei oder dieses Profils hinzugekommen sind';

  @override
  String get importDupExisting => 'Schon in der App';

  @override
  String get importDupBatch => 'Doppelt in diesem Import';

  @override
  String get importDupAlready => 'Früher importiert';

  @override
  String get importDupNone => 'Keine Duplikate gefunden.';

  @override
  String get importDupSkipAll => 'Alle überspringen';

  @override
  String get importDupImportAll => 'Alle importieren';

  @override
  String importDupIncluded(int included, int total) {
    return '$included von $total aufgenommen';
  }

  @override
  String importAlreadyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zeilen wurden früher importiert und werden übersprungen.',
      one: '1 Zeile wurde früher importiert und wird übersprungen.',
    );
    return '$_temp0';
  }

  @override
  String get importSummaryReady => 'Bereit zum Import';

  @override
  String importSummaryTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Buchungen',
      one: '1 Buchung',
    );
    return '$_temp0';
  }

  @override
  String importSummaryTransfers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inkl. $count Umbuchungen',
      one: 'inkl. 1 Umbuchung',
    );
    return '$_temp0';
  }

  @override
  String importSummarySkipped(int count) {
    return '$count Duplikate übersprungen';
  }

  @override
  String importSummaryAlready(int count) {
    return '$count schon importiert';
  }

  @override
  String importSummaryInvalid(int count) {
    return '$count unlesbare Zeilen';
  }

  @override
  String importSummaryRules(int count) {
    return '$count durch Regeln kategorisiert';
  }

  @override
  String importSummaryNew(int accounts, int categories, int tags) {
    return 'Neu: $accounts Konten · $categories Kategorien · $tags Tags';
  }

  @override
  String get importResultingBalances => 'Kontostände danach';

  @override
  String get importByCategory => 'Nach Kategorie';

  @override
  String importStartsAt(String amount) {
    return 'Beginnt bei $amount';
  }

  @override
  String get importMatchesSheet => 'Stimmt mit der Tabelle überein';

  @override
  String importSheetSays(String amount) {
    return 'Tabelle: $amount';
  }

  @override
  String get importNewBadge => 'Neu';

  @override
  String get importUncategorised => 'Ohne Kategorie';

  @override
  String get importWarnings => 'Hinweise';

  @override
  String importWarnInvalid(int count) {
    return '$count Zeilen sind nicht lesbar und werden nicht importiert.';
  }

  @override
  String importWarnMismatch(int count, String account) {
    return '$count Saldo-Abweichungen in $account.';
  }

  @override
  String importWarnFormulas(int count) {
    return '$count Formelzellen haben kein gespeichertes Ergebnis. Öffne die Datei in Excel, speichere sie und importiere erneut.';
  }

  @override
  String importWarnYear(int count) {
    return '$count Daten liegen außerhalb des Jahres ihres Blatts.';
  }

  @override
  String importWarnUncategorised(int count) {
    return '$count Buchungen haben keine Kategorie.';
  }

  @override
  String importWarnDuplicates(int count) {
    return '$count mögliche Duplikate werden importiert.';
  }

  @override
  String get importApplyRules => 'Regeln auf Zeilen ohne Kategorie anwenden';

  @override
  String get importSetOpening =>
      'Anfangssaldo neuer Konten aus dem Kontostand übernehmen';

  @override
  String get importSaveProfile => 'Einstellungen als Profil speichern';

  @override
  String get importProfileName => 'Profilname';

  @override
  String importUpdateProfile(String name) {
    return 'Profil „$name“ aktualisieren';
  }

  @override
  String importCommit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Buchungen importieren',
      one: '1 Buchung importieren',
      zero: 'Nichts zu importieren',
    );
    return '$_temp0';
  }

  @override
  String importFailed(String message) {
    return 'Der Import ist fehlgeschlagen; es wurde nichts gespeichert. $message';
  }

  @override
  String get importDoneTitle => 'Import abgeschlossen';

  @override
  String importDoneMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Buchungen wurden importiert.',
      one: '1 Buchung wurde importiert.',
    );
    return '$_temp0';
  }

  @override
  String get importShowTransactions => 'Buchungen anzeigen';

  @override
  String get importAgain => 'Weiteren Import starten';

  @override
  String get importUndo => 'Import rückgängig machen';

  @override
  String get importUndone => 'Import rückgängig gemacht';

  @override
  String get importHistoryTab => 'Verlauf';

  @override
  String get importProfilesTab => 'Profile';

  @override
  String get importHistoryEmpty => 'Noch keine Importe.';

  @override
  String get importNew => 'Neuer Import';

  @override
  String importHistoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Buchungen',
      one: '1 Buchung',
    );
    return '$_temp0';
  }

  @override
  String importHistoryLive(int live, int total) {
    return '$live von $total noch vorhanden';
  }

  @override
  String importHistoryUndone(String date) {
    return 'Rückgängig gemacht am $date';
  }

  @override
  String get importHistoryUndoTitle => 'Diesen Import rückgängig machen?';

  @override
  String importHistoryUndoMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alle $count Buchungen dieses Imports werden gelöscht.',
      one: 'Die Buchung dieses Imports wird gelöscht.',
    );
    return '$_temp0 Dabei angelegte Konten, Kategorien und Tags werden entfernt, wenn nichts anderes sie nutzt.';
  }

  @override
  String get importHistoryUndoAction => 'Rückgängig machen';

  @override
  String get importProfilesEmpty =>
      'Noch keine Profile. Speichere eines im letzten Schritt eines Imports.';

  @override
  String get importProfileExport => 'Exportieren';

  @override
  String get importProfileRename => 'Umbenennen';

  @override
  String get importProfileExported => 'Profil gespeichert';

  @override
  String get importProfileImported => 'Profil importiert';

  @override
  String get importProfileStart => 'Mit diesem Profil importieren';

  @override
  String get onbDefaultChecking => 'Girokonto';

  @override
  String onbStepOf(int current, int total) {
    return 'Schritt $current von $total';
  }

  @override
  String get onbGetStarted => 'Los geht\'s';

  @override
  String get onbSetUpLock => 'App-Sperre einrichten';

  @override
  String get onbSkipFinish => 'Jetzt nicht, fertig';

  @override
  String get onbTagline =>
      'Dein Geld, auf deinem Gerät. Erfassen, verfolgen, planen und vorausschauen – ohne Cloud-Konto.';

  @override
  String get onbPointRecord => 'Buchungen in Sekunden erfassen';

  @override
  String get onbPointTrack => 'Salden, Vermögen und Ausgaben im Blick';

  @override
  String get onbPointPlan => 'Budgets, wiederkehrende Rechnungen und Sparziele';

  @override
  String get onbPointProject => 'Kontostand Monate im Voraus prognostizieren';

  @override
  String get onbPointPrivate =>
      'Privat: verschlüsselt auf diesem Gerät, keine Telemetrie';

  @override
  String get onbFormatsTitle => 'Sprache & Formate';

  @override
  String get onbFormatsSubtitle =>
      'Alles lässt sich später in den Einstellungen ändern.';

  @override
  String get onbPreview => 'Vorschau';

  @override
  String get onbPeriodTitle => 'Budgetzeitraum';

  @override
  String get onbPeriodSubtitle =>
      'Wann beginnt dein Geldmonat? Viele nehmen den Tag des Gehaltseingangs.';

  @override
  String get onbLastDayOfMonth => 'Letzter Tag des Monats';

  @override
  String get onbSalaryHint =>
      'Tipp: Sobald dein Gehalt als wiederkehrende Einnahme angelegt ist, können Zeiträume am Zahltag beginnen (Einstellungen › Budgets).';

  @override
  String get onbStartTitle => 'Wie möchtest du starten?';

  @override
  String get onbStartSubtitle =>
      'Standardkategorien werden in beiden Fällen angelegt.';

  @override
  String get onbImportTitle => 'Aus Excel oder CSV importieren';

  @override
  String get onbImportText =>
      'Übernimm deine bestehende Tabelle mit der gesamten Historie. Der Import ordnet Spalten, Kategorien und Konten zu.';

  @override
  String get onbFreshTitle => 'Neu beginnen';

  @override
  String get onbFreshText =>
      'Lege deine Konten mit dem aktuellen Kontostand an.';

  @override
  String get onbAccountsTitle => 'Deine Konten';

  @override
  String get onbAccountsSubtitle =>
      'Gib für jedes Konto den heutigen Kontostand ein. Weitere kannst du später hinzufügen.';

  @override
  String get onbAccountName => 'Name';

  @override
  String get onbAccountType => 'Art';

  @override
  String get onbOpeningBalance => 'Aktueller Kontostand';

  @override
  String get onbAddAccount => 'Weiteres Konto hinzufügen';

  @override
  String get onbLockTitle => 'Schütze deine Daten';

  @override
  String get onbLockSubtitle =>
      'Sperre die App mit PIN, Passwort oder Biometrie.';

  @override
  String get onbTypeChecking => 'Girokonto';

  @override
  String get onbTypeSavings => 'Sparkonto';

  @override
  String get onbTypeCash => 'Bargeld';

  @override
  String get onbTypeCreditCard => 'Kreditkarte';

  @override
  String get onbTypeInvestment => 'Depot';

  @override
  String get onbTypeLoan => 'Kredit';

  @override
  String get onbTypeOtherAsset => 'Sonstiges Vermögen';

  @override
  String get onbTypeOtherLiability => 'Sonstige Verbindlichkeit';

  @override
  String get planTabBudgets => 'Budgets';

  @override
  String get planTabRecurring => 'Wiederkehrend';

  @override
  String get planTabGoals => 'Ziele';

  @override
  String get planBillsCalendar => 'Zahlungskalender';

  @override
  String get planPreviousPeriod => 'Vorheriger Zeitraum';

  @override
  String get planNextPeriod => 'Nächster Zeitraum';

  @override
  String get planToday => 'Heute';

  @override
  String planPeriodSemantics(String title, String range) {
    return 'Zeitraum $title, $range';
  }

  @override
  String get recurringNew => 'Neuer Dauerauftrag';

  @override
  String get recurringEdit => 'Dauerauftrag bearbeiten';

  @override
  String get recurringEmpty =>
      'Noch keine wiederkehrenden Buchungen. Füge Miete, Gehalt oder Abos hinzu, um sie kommen zu sehen.';

  @override
  String get recurringSelectHint =>
      'Wähle eine wiederkehrende Buchung zum Bearbeiten.';

  @override
  String get recurringNext30Days => 'Nächste 30 Tage';

  @override
  String recurringBills(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zahlungen',
      one: '1 Zahlung',
      zero: 'Keine Zahlungen',
    );
    return '$_temp0';
  }

  @override
  String recurringIncomeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einnahmen',
      one: '1 Einnahme',
      zero: 'Keine Einnahmen',
    );
    return '$_temp0';
  }

  @override
  String get recurringDueTitle => 'Warten auf Bestätigung';

  @override
  String get recurringDueToday => 'Heute fällig';

  @override
  String recurringOverdueDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Seit $days Tagen überfällig',
      one: 'Seit 1 Tag überfällig',
    );
    return '$_temp0';
  }

  @override
  String recurringDueInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days Tagen',
      one: 'Morgen',
    );
    return '$_temp0';
  }

  @override
  String recurringMorePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count weitere fällig',
      one: '+1 weitere fällig',
    );
    return '$_temp0';
  }

  @override
  String get recurringSkip => 'Überspringen';

  @override
  String get recurringEditConfirm => 'Ändern & bestätigen';

  @override
  String recurringConfirmed(String name) {
    return '„$name“ gebucht';
  }

  @override
  String recurringSkipped(String name) {
    return '„$name“ übersprungen';
  }

  @override
  String recurringActiveRules(int count) {
    return 'Aktiv ($count)';
  }

  @override
  String get recurringInactiveRules => 'Pausiert oder beendet';

  @override
  String get recurringNoActive => 'Keine aktiven wiederkehrenden Buchungen.';

  @override
  String get recurringPaused => 'Pausiert';

  @override
  String get recurringEnded => 'Beendet';

  @override
  String recurringNextOn(String date) {
    return 'Nächste $date';
  }

  @override
  String get recurringAutoPostShort => 'automatisch';

  @override
  String get recurringConfirmShort => 'bestätigen';

  @override
  String get recurringPostedLabel => 'gebucht';

  @override
  String get recurringWhat => 'Was';

  @override
  String get recurringWhen => 'Wann';

  @override
  String get recurringPosting => 'Buchung & Erinnerungen';

  @override
  String get recurringName => 'Name';

  @override
  String get recurringFromAccount => 'Von Konto';

  @override
  String get recurringToAccount => 'Auf Konto';

  @override
  String get recurringNotSet => 'Nicht festgelegt';

  @override
  String get recurringSplit => 'Auf Kategorien aufteilen';

  @override
  String get recurringAddSplit => 'Zeile hinzufügen';

  @override
  String get recurringSplitBalanced => 'Aufteilung stimmt';

  @override
  String recurringSplitRemainder(String amount) {
    return '$amount nicht zugeordnet';
  }

  @override
  String get recurringTags => 'Tags';

  @override
  String get recurringRepeats => 'Wiederholung';

  @override
  String get recurringPresetMonthly => 'Monatlich an einem Tag';

  @override
  String get recurringPresetLastDay => 'Letzter Tag des Monats';

  @override
  String get recurringPresetLastBusinessDay => 'Letzter Werktag des Monats';

  @override
  String get recurringPresetWeekly => 'Wöchentlich';

  @override
  String get recurringPresetQuarterly => 'Vierteljährlich';

  @override
  String get recurringPresetYearly => 'Jährlich';

  @override
  String get recurringPresetDaily => 'Täglich';

  @override
  String get recurringPresetCustom => 'Benutzerdefiniert (RRULE)';

  @override
  String get recurringDayOfMonth => 'Tag im Monat';

  @override
  String get recurringMonthEndHint =>
      'In kürzeren Monaten wird der letzte Tag verwendet.';

  @override
  String get recurringEveryNMonths => 'Alle … Monate';

  @override
  String get recurringEveryNWeeks => 'Alle … Wochen';

  @override
  String get recurringEveryNYears => 'Alle … Jahre';

  @override
  String get recurringEveryNDays => 'Alle … Tage';

  @override
  String get recurringMonth => 'Monat';

  @override
  String get recurringDay => 'Tag';

  @override
  String get recurringRRule => 'Wiederholungsregel (RRULE)';

  @override
  String get recurringRRuleHelp =>
      'RFC 5545, z. B. FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=15';

  @override
  String get recurringRRuleInvalid => 'Dieser Zeitplan ist ungültig.';

  @override
  String get recurringDecrease => 'Verringern';

  @override
  String get recurringIncrease => 'Erhöhen';

  @override
  String get recurringStartDate => 'Beginnt';

  @override
  String get recurringEnds => 'Endet';

  @override
  String get recurringEndsNever => 'Nie';

  @override
  String get recurringEndsOnDate => 'Am Datum';

  @override
  String get recurringEndsAfterCount => 'Nach …';

  @override
  String get recurringEndDate => 'Enddatum';

  @override
  String get recurringOccurrences => 'Anzahl der Termine';

  @override
  String get recurringShift => 'An Wochenenden und Feiertagen';

  @override
  String get recurringShiftNone => 'Datum behalten';

  @override
  String get recurringShiftEarlier => 'Früher';

  @override
  String get recurringShiftLater => 'Später';

  @override
  String get recurringAutoPostHelp =>
      'Wird am Fälligkeitstag beim App-Start automatisch gebucht.';

  @override
  String get recurringRemindHelp =>
      'Du bestätigst (oder überspringst) jeden Termin, er wird nicht von selbst gebucht.';

  @override
  String recurringRemindDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage vorher erinnern',
      one: '1 Tag vorher erinnern',
      zero: 'Am Fälligkeitstag erinnern',
    );
    return '$_temp0';
  }

  @override
  String get recurringNotifyTime => 'Uhrzeit der Benachrichtigung';

  @override
  String get recurringActive => 'Aktiv';

  @override
  String get recurringActiveHelp =>
      'Pausierte Buchungen werden weder gebucht noch erinnert.';

  @override
  String get recurringAmountChanges => 'Betragsänderungen';

  @override
  String get recurringAmountChangesHelp =>
      'Ein neuer Betrag ab einem Datum (z. B. eine Mieterhöhung). Frühere Buchungen bleiben unverändert.';

  @override
  String get recurringAddAmountChange => 'Betragsänderung hinzufügen';

  @override
  String recurringFromDate(String date) {
    return 'Ab $date';
  }

  @override
  String get recurringEffectiveFrom => 'Gültig ab';

  @override
  String get recurringNewAmount => 'Neuer Betrag';

  @override
  String get recurringNextOccurrences => 'Nächste Termine';

  @override
  String get recurringNoUpcoming => 'Keine kommenden Termine.';

  @override
  String recurringShiftedFrom(String date, String original) {
    return '$date (verschoben vom $original)';
  }

  @override
  String recurringLastPosted(String date) {
    return 'Erledigt bis $date';
  }

  @override
  String get recurringPostedHistory => 'Gebucht';

  @override
  String get recurringNothingPosted => 'Noch nichts gebucht.';

  @override
  String get recurringSaved => 'Wiederkehrende Buchung gespeichert';

  @override
  String get recurringDeleteMessage =>
      'Bereits gebuchte Transaktionen bleiben erhalten.';

  @override
  String get recurringNotFound =>
      'Diese wiederkehrende Buchung existiert nicht mehr.';

  @override
  String get recurringErrorName => 'Gib einen Namen ein';

  @override
  String get recurringErrorAmount => 'Gib einen Betrag ein';

  @override
  String get recurringErrorEndBeforeStart =>
      'Das Enddatum darf nicht vor dem Beginn liegen';

  @override
  String get recurringErrorCount => 'Gib mindestens 1 ein';

  @override
  String get recurringErrorAccount => 'Wähle ein Konto';

  @override
  String get recurringErrorTransferAccount => 'Wähle das Zielkonto';

  @override
  String get recurringErrorSameAccount => 'Wähle zwei verschiedene Konten';

  @override
  String get recurringErrorSplits => 'Die Aufteilung muss den Betrag ergeben';

  @override
  String get recurringPickRule => 'Wiederkehrende Buchung wählen';

  @override
  String get recurringPickIncome => 'Gehalt wählen';

  @override
  String get recurringNoIncomeRules =>
      'Noch keine wiederkehrende Einnahme. Lege dein Gehalt zuerst als wiederkehrende Einnahme an.';

  @override
  String get recurringNothingOnDay => 'An diesem Tag ist nichts fällig.';

  @override
  String get recurringMonthOut => 'Zahlungen diesen Monat';

  @override
  String get recurringMonthIn => 'Einnahmen diesen Monat';

  @override
  String recurringReminderBillBody(String amount, String date) {
    return '$amount fällig am $date';
  }

  @override
  String recurringReminderIncomeBody(String amount, String date) {
    return '$amount erwartet am $date';
  }

  @override
  String get recurringChannelBills => 'Zahlungserinnerungen';

  @override
  String get recurringChannelIncome => 'Einnahme-Erinnerungen';

  @override
  String get recurringChannelLowBalance => 'Niedriger Kontostand';

  @override
  String get recurringChannelBudgets => 'Budgetwarnungen';

  @override
  String get reportsTitle => 'Berichte';

  @override
  String get reportsSpendingTitle => 'Ausgaben nach Kategorie';

  @override
  String get reportsIncomeByCategoryTitle => 'Einnahmen nach Kategorie';

  @override
  String get reportsIncomeExpenseTitle => 'Einnahmen und Ausgaben';

  @override
  String get reportsNetWorthTitle => 'Vermögen';

  @override
  String get reportsCategoryTrendTitle => 'Kategorieverlauf';

  @override
  String get reportsTopPayeesTitle => 'Top-Empfänger';

  @override
  String get reportsComparisonTitle => 'Periodenvergleich';

  @override
  String get reportsPeriod => 'Zeitraum';

  @override
  String get reportsCustomRange => 'Eigener Zeitraum…';

  @override
  String get reportsPreviousPeriod => 'Vorheriger Zeitraum';

  @override
  String get reportsNextPeriod => 'Nächster Zeitraum';

  @override
  String get reportsAllAccounts => 'Alle Konten';

  @override
  String reportsAccountsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten',
      one: '1 Konto',
    );
    return '$_temp0';
  }

  @override
  String get reportsAllTags => 'Alle Tags';

  @override
  String reportsTagsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tags',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get reportsCustomField => 'Eigenes Feld';

  @override
  String reportsCustomFieldValue(String field, String value) {
    return '$field: $value';
  }

  @override
  String get reportsChooseField => 'Feld';

  @override
  String get reportsFieldValue => 'Wert';

  @override
  String get reportsNoFields => 'Noch keine eigenen Felder';

  @override
  String get reportsIncludeExcluded => 'Ausgeschlossene einbeziehen';

  @override
  String get reportsIncludeExcludedHint =>
      'Bezieht die unter Einstellungen › Berichte ausgeschlossenen Kategorien, Konten und Tags ein';

  @override
  String get reportsClearFilters => 'Filter zurücksetzen';

  @override
  String get reportsExportCsv => 'Als CSV exportieren';

  @override
  String get reportsExported => 'Bericht exportiert';

  @override
  String reportsExportFailed(String message) {
    return 'Export fehlgeschlagen: $message';
  }

  @override
  String get reportsNoData => 'Keine Daten in diesem Zeitraum';

  @override
  String get reportsTotal => 'Summe';

  @override
  String get reportsUncategorized => 'Ohne Kategorie';

  @override
  String get reportsOther => 'Sonstige';

  @override
  String get reportsArchived => 'archiviert';

  @override
  String get reportsData => 'Daten';

  @override
  String get reportsColShare => 'Anteil';

  @override
  String get reportsColCount => 'Buchungen';

  @override
  String get reportsColPeriod => 'Zeitraum';

  @override
  String get reportsColIncome => 'Einnahmen';

  @override
  String get reportsColExpenses => 'Ausgaben';

  @override
  String get reportsColNet => 'Saldo';

  @override
  String get reportsColSavingsRate => 'Sparquote';

  @override
  String get reportsColMonth => 'Monat';

  @override
  String get reportsColAssets => 'Vermögenswerte';

  @override
  String get reportsColLiabilities => 'Verbindlichkeiten';

  @override
  String get reportsColNetWorth => 'Vermögen';

  @override
  String get reportsColAverage => 'Durchschnitt';

  @override
  String get reportsColCurrent => 'Aktuell';

  @override
  String get reportsColPrevious => 'Vorher';

  @override
  String get reportsColLastYear => 'Vorjahr';

  @override
  String get reportsColDeltaPrevious => 'Δ Vorher';

  @override
  String get reportsColDeltaPreviousPct => 'Δ Vorher %';

  @override
  String get reportsColDeltaLastYear => 'Δ Vorjahr';

  @override
  String get reportsColDeltaLastYearPct => 'Δ Vorjahr %';

  @override
  String get reportsIntervalMonth => 'Monat';

  @override
  String get reportsIntervalQuarter => 'Quartal';

  @override
  String get reportsIntervalYear => 'Jahr';

  @override
  String get reportsIntervalBudgetPeriod => 'Budgetzeitraum';

  @override
  String get reportsSortTotal => 'Summe';

  @override
  String get reportsSortCount => 'Anzahl';

  @override
  String get reportsSortAverage => 'Durchschnitt';

  @override
  String get reportsAllCategories => 'Alle Kategorien';

  @override
  String get reportsShowTransactions => 'Buchungen anzeigen';

  @override
  String get reportsSubcategories => 'Unterkategorien anzeigen';

  @override
  String get reportsChooseCategories => 'Kategorien';

  @override
  String get reportsTopCategoriesAuto => 'Top-3-Kategorien';

  @override
  String get reportsSavingsRate => 'Sparquote';

  @override
  String get reportsNetChange => 'Veränderung';

  @override
  String reportsChangeInPeriod(String amount) {
    return '$amount in diesem Zeitraum';
  }

  @override
  String get reportsVsPrevious => 'ggü. Vorzeitraum';

  @override
  String get reportsVsLastYear => 'ggü. Vorjahreszeitraum';

  @override
  String reportsQuarterLabel(int quarter, String year) {
    return 'Q$quarter $year';
  }

  @override
  String reportsDonutSummary(String title, String total, String items) {
    return '$title, Summe $total. $items';
  }

  @override
  String reportsBarsSummary(int count, String income, String expenses) {
    return 'Einnahmen und Ausgaben über $count Zeiträume: Einnahmen $income, Ausgaben $expenses.';
  }

  @override
  String reportsLineSummary(String from, String to, String start, String end) {
    return 'Vermögen von $from bis $to: $start bis $end.';
  }

  @override
  String reportsTrendSummary(int count, String items) {
    return 'Kategorieverlauf über $count Zeiträume. $items';
  }

  @override
  String reportsPayeesSummary(String items) {
    return 'Top-Empfänger: $items';
  }

  @override
  String reportsComparisonSummary(
    String current,
    String previous,
    String lastYear,
  ) {
    return 'Summe $current, Vorzeitraum $previous, Vorjahr $lastYear.';
  }

  @override
  String get reportsOpenReport => 'Bericht öffnen';

  @override
  String get reportsNotFound => 'Bericht nicht gefunden';

  @override
  String get rulesTitle => 'Regeln';

  @override
  String get rulesEmpty =>
      'Noch keine Regeln. Regeln setzen Kategorie, Tags und mehr, wenn Empfänger, Notiz oder Betrag passen.';

  @override
  String get rulesAdd => 'Neue Regel';

  @override
  String get rulesOrderHint =>
      'Regeln laufen von oben nach unten. Für jedes Feld gewinnt die erste passende Regel; zum Umsortieren ziehen.';

  @override
  String get rulesDisabled => 'Deaktiviert';

  @override
  String get rulesEnable => 'Aktiv';

  @override
  String get rulesRerun => 'Regeln erneut anwenden';

  @override
  String get rulesRerunTitle => 'Regeln auf bestehende Buchungen anwenden';

  @override
  String get rulesRerunOnlyUncategorised => 'Nur Buchungen ohne Kategorie';

  @override
  String get rulesRerunAllHint =>
      'Regeln prüfen jede Buchung neu und ersetzen bestehende Kategorien, Notizen und Status.';

  @override
  String rulesRerunPreview(int count, int scanned) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Buchungen würden sich ändern',
      one: '1 Buchung würde sich ändern',
      zero: 'Keine Buchung würde sich ändern',
    );
    return '$_temp0 ($scanned geprüft)';
  }

  @override
  String get rulesRerunApply => 'Anwenden';

  @override
  String rulesRerunDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Buchungen aktualisiert',
      one: '1 Buchung aktualisiert',
      zero: 'Nichts geändert',
    );
    return '$_temp0';
  }

  @override
  String get rulesNoRules => 'Es gibt keine aktiven Regeln.';

  @override
  String get rulesNew => 'Neue Regel';

  @override
  String get rulesEdit => 'Regel bearbeiten';

  @override
  String get rulesName => 'Name';

  @override
  String get rulesConditions => 'Wenn';

  @override
  String get rulesMatchAll => 'Alle passen';

  @override
  String get rulesMatchAny => 'Eine passt';

  @override
  String get rulesAddCondition => 'Bedingung hinzufügen';

  @override
  String get rulesCondText => 'Text in Empfänger / Notiz';

  @override
  String get rulesCondAmount => 'Betragsbereich';

  @override
  String get rulesCondAccount => 'Konto';

  @override
  String get rulesCondType => 'Art';

  @override
  String get rulesFieldPayee => 'Empfänger';

  @override
  String get rulesFieldNote => 'Notiz';

  @override
  String get rulesFieldPayeeOrNote => 'Empfänger oder Notiz';

  @override
  String get rulesOpContains => 'enthält';

  @override
  String get rulesOpEquals => 'ist';

  @override
  String get rulesOpStartsWith => 'beginnt mit';

  @override
  String get rulesOpEndsWith => 'endet mit';

  @override
  String get rulesOpRegex => 'passt zu Regex';

  @override
  String get rulesNegate => 'Umkehren (passt nicht)';

  @override
  String get rulesText => 'Text';

  @override
  String get rulesInvalidRegex => 'Ungültiger regulärer Ausdruck';

  @override
  String get rulesAmountMin => 'Von';

  @override
  String get rulesAmountMax => 'Bis';

  @override
  String get rulesAmountAbs => 'Vorzeichen ignorieren';

  @override
  String get rulesChooseAccounts => 'Konten wählen';

  @override
  String rulesAccountsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten',
      one: '1 Konto',
      zero: 'Kein Konto',
    );
    return '$_temp0';
  }

  @override
  String get rulesRemoveCondition => 'Bedingung entfernen';

  @override
  String get rulesActions => 'Dann';

  @override
  String get rulesActCategory => 'Kategorie setzen';

  @override
  String get rulesActTags => 'Tags hinzufügen';

  @override
  String get rulesActPayee => 'Empfänger umbenennen in';

  @override
  String get rulesActNote => 'Notiz setzen';

  @override
  String get rulesActStatus => 'Status setzen';

  @override
  String get rulesActCustomFields => 'Eigene Felder setzen';

  @override
  String get rulesKeep => 'Nicht ändern';

  @override
  String get rulesOverwrite => 'Vorhandene Werte ersetzen';

  @override
  String get rulesOverwriteHint =>
      'Sonst füllt die Regel nur leere Felder. Das Umbenennen des Empfängers gilt immer.';

  @override
  String get rulesApplyOnEntry => 'Beim Erfassen anwenden';

  @override
  String get rulesApplyOnImport => 'Beim Import anwenden';

  @override
  String get rulesTest => 'Ausprobieren';

  @override
  String get rulesTestHint =>
      'Gib ein Beispiel ein, um zu sehen, was die Regel tut.';

  @override
  String get rulesTestAmount => 'Betrag (negativ = Ausgabe)';

  @override
  String get rulesTestMatch => 'Passt – würde setzen:';

  @override
  String get rulesTestNoMatch => 'Passt nicht';

  @override
  String get rulesTestNoChange => 'Passt, aber die Felder sind schon gesetzt';

  @override
  String get rulesSaved => 'Regel gespeichert';

  @override
  String get rulesDeleted => 'Regel gelöscht';

  @override
  String get rulesInvalid =>
      'Gib der Regel einen Namen, mindestens eine vollständige Bedingung und eine Aktion.';

  @override
  String get rulesCreateFromTxn => 'Regel aus dieser Buchung erstellen';

  @override
  String rulesSummaryWhen(String condition) {
    return 'Wenn $condition';
  }

  @override
  String rulesSummaryAmount(String range) {
    return 'Betrag $range';
  }

  @override
  String get rulesSummaryAnd => ' und ';

  @override
  String get rulesSummaryOr => ' oder ';

  @override
  String get rulesSummaryNoConditions => 'Keine Bedingungen';

  @override
  String get rulesYes => 'Ja';

  @override
  String get rulesNo => 'Nein';

  @override
  String get scenariosTitle => 'Szenarien';

  @override
  String get scenariosNew => 'Neues Szenario';

  @override
  String get scenariosEdit => 'Szenario bearbeiten';

  @override
  String get scenariosEmpty =>
      'Noch keine Szenarien. Ein Szenario verändert den Plan – eine Gehaltserhöhung, eine große Anschaffung, das Ende eines Kredits – ohne deine Daten anzufassen.';

  @override
  String get scenariosName => 'Name';

  @override
  String get scenariosNameRequired => 'Gib einen Namen ein';

  @override
  String get scenariosColor => 'Farbe';

  @override
  String get scenariosColorAuto => 'Automatisch';

  @override
  String scenariosColorOption(int index) {
    return 'Farbe $index';
  }

  @override
  String get scenariosCompare => 'In der Prognose vergleichen';

  @override
  String get scenariosCompareDesc =>
      'Bis zu 3 Szenarien werden neben der Basis angezeigt.';

  @override
  String get scenariosMaxCompared =>
      'Es lassen sich höchstens 3 Szenarien vergleichen. Schalte zuerst eines aus.';

  @override
  String get scenariosChanges => 'Änderungen';

  @override
  String get scenariosAddChange => 'Änderung hinzufügen';

  @override
  String get scenariosNoChanges =>
      'Noch keine Änderungen. Füge eine hinzu, um ihre Wirkung zu sehen.';

  @override
  String get scenariosDuplicate => 'Duplizieren';

  @override
  String scenariosCopyName(Object name) {
    return '$name (Kopie)';
  }

  @override
  String get scenariosDeleteTitle => 'Szenario löschen?';

  @override
  String scenariosDeleteMessage(Object name) {
    return '„$name“ wird gelöscht. Deine Daten bleiben unverändert.';
  }

  @override
  String get scenariosNotFound => 'Dieses Szenario gibt es nicht mehr.';

  @override
  String get scenariosModuleOff =>
      'Szenarien sind ausgeschaltet. Du kannst sie unter Einstellungen › Navigation & Module einschalten.';

  @override
  String get scenariosSaved => 'Szenario gespeichert';

  @override
  String scenariosChangeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Änderungen',
      one: '1 Änderung',
      zero: 'Keine Änderungen',
    );
    return '$_temp0';
  }

  @override
  String get scenariosTypeOneOff => 'Einmaliges Ereignis';

  @override
  String get scenariosTypeCategory => 'Ausgaben einer Kategorie ändern';

  @override
  String get scenariosTypeRecurringChange => 'Wiederkehrenden Posten ändern';

  @override
  String get scenariosTypeAddRecurring => 'Wiederkehrenden Posten hinzufügen';

  @override
  String get scenariosTypeEndRecurring => 'Wiederkehrenden Posten beenden';

  @override
  String get scenariosTypeReturn => 'Andere Rendite';

  @override
  String get scenariosTypeInflation => 'Andere Inflation';

  @override
  String get scenariosTypeUnknown => 'Nicht unterstützte Änderung';

  @override
  String scenariosSumOneOff(String amount, String date) {
    return 'Einmalig · $amount am $date';
  }

  @override
  String scenariosSumPercent(String percent, String date) {
    return '$percent ab $date';
  }

  @override
  String scenariosSumCategoryAbsolute(String amount, String date) {
    return '$amount pro Monat ab $date';
  }

  @override
  String scenariosSumRecurringAbsolute(String amount, String date) {
    return '$amount je Zahlung ab $date';
  }

  @override
  String scenariosSumAddRecurring(
    String amount,
    String frequency,
    String date,
  ) {
    return '$amount $frequency ab $date';
  }

  @override
  String scenariosSumEndRecurring(Object date) {
    return 'Endet am $date';
  }

  @override
  String scenariosSumReturnAll(Object percent) {
    return 'Rendite $percent auf Geldanlagen';
  }

  @override
  String scenariosSumReturnAccount(String percent, String account) {
    return 'Rendite $percent auf $account';
  }

  @override
  String scenariosSumInflation(Object percent) {
    return 'Inflation $percent';
  }

  @override
  String get scenariosUnknownItem => 'Unbekannt';

  @override
  String get scenariosFieldLabel => 'Bezeichnung';

  @override
  String get scenariosFieldDate => 'Datum';

  @override
  String get scenariosFieldFrom => 'Ab';

  @override
  String get scenariosFieldUntil => 'Bis (optional)';

  @override
  String get scenariosFieldAmount => 'Betrag';

  @override
  String get scenariosFieldAccount => 'Konto';

  @override
  String get scenariosFieldTransferTo => 'Umbuchung auf (optional)';

  @override
  String get scenariosFieldCategory => 'Kategorie';

  @override
  String get scenariosFieldRule => 'Wiederkehrender Posten';

  @override
  String get scenariosFieldChangeBy => 'Ändern um';

  @override
  String get scenariosModePercent => 'Prozent';

  @override
  String get scenariosModeAmount => 'Betrag';

  @override
  String get scenariosFieldPercent => 'Änderung in % (z. B. 5 oder −10)';

  @override
  String get scenariosFieldDeltaMonthly =>
      'Änderung pro Monat (negativ = weniger)';

  @override
  String get scenariosFieldDeltaEach =>
      'Änderung je Zahlung (negativ = weniger)';

  @override
  String get scenariosFieldRepeats => 'Wiederholung';

  @override
  String get scenariosFreqWeekly => 'wöchentlich';

  @override
  String get scenariosFreqMonthly => 'monatlich';

  @override
  String get scenariosFreqQuarterly => 'alle 3 Monate';

  @override
  String get scenariosFreqYearly => 'jährlich';

  @override
  String get scenariosFreqCustom => 'benutzerdefiniert';

  @override
  String get scenariosFieldReturn => 'Erwartete Rendite pro Jahr in %';

  @override
  String get scenariosFieldInflation => 'Inflation pro Jahr in %';

  @override
  String get scenariosAllInvestments => 'Alle Geldanlagen';

  @override
  String get scenariosInvalidNumber => 'Gib eine gültige Zahl ein';

  @override
  String get scenariosRequired => 'Pflichtfeld';

  @override
  String get scenariosChoose => 'Auswählen …';

  @override
  String get scenariosNoRules => 'Es gibt noch keine wiederkehrenden Posten.';

  @override
  String scenariosLowDelta(Object delta) {
    return 'Tiefster $delta';
  }

  @override
  String scenariosEndDelta(Object delta) {
    return 'Ende $delta';
  }

  @override
  String get scenariosResolvesWarning => 'Bleibt über deiner Schwelle';

  @override
  String get scenariosCausesWarning => 'Fällt unter deine Schwelle';

  @override
  String get securityLockedTitle => 'Quiet Ledger ist gesperrt';

  @override
  String get securityEnterPin => 'PIN eingeben';

  @override
  String get securityEnterPassword => 'Passwort eingeben';

  @override
  String get securityUnlock => 'Entsperren';

  @override
  String get securityUseBiometrics => 'Mit Biometrie entsperren';

  @override
  String get securityBiometricReason => 'Quiet Ledger entsperren';

  @override
  String get securityWrongPin => 'Falsche PIN';

  @override
  String get securityWrongPassword => 'Falsches Passwort';

  @override
  String securityAttemptsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Noch $count Versuche bis zur Wartezeit',
      one: 'Noch 1 Versuch bis zur Wartezeit',
    );
    return '$_temp0';
  }

  @override
  String securityTryAgainIn(String time) {
    return 'Zu viele Versuche. Erneut versuchen in $time.';
  }

  @override
  String get securityChecking => 'Wird geprüft …';

  @override
  String get securityDeleteDigit => 'Ziffer löschen';

  @override
  String securityDigitsOf(int count, int total) {
    return '$count von $total Ziffern eingegeben';
  }

  @override
  String securityDigitsEntered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ziffern eingegeben',
      one: '1 Ziffer eingegeben',
      zero: 'Keine Ziffern eingegeben',
    );
    return '$_temp0';
  }

  @override
  String get securityPasswordLabel => 'Passwort';

  @override
  String get securityShowPassword => 'Passwort anzeigen';

  @override
  String get securityHidePassword => 'Passwort verbergen';

  @override
  String get securitySetupTitle => 'App-Sperre einrichten';

  @override
  String get securityChooseMethod => 'Wie möchtest du die App entsperren?';

  @override
  String get securityMethodPin => 'PIN';

  @override
  String get securityMethodPassword => 'Passwort';

  @override
  String get securityAlsoBiometrics => 'Auch mit Biometrie entsperren';

  @override
  String get securityAlsoBiometricsDesc =>
      'Fingerabdruck, Gesicht oder Windows Hello. PIN oder Passwort bleiben als Ausweichlösung.';

  @override
  String get securityNewPin => 'PIN festlegen';

  @override
  String get securityConfirmPin => 'PIN wiederholen';

  @override
  String get securityNewPassword => 'Passwort festlegen';

  @override
  String get securityConfirmPassword => 'Passwort wiederholen';

  @override
  String get securityMismatch =>
      'Die Eingaben stimmen nicht überein. Bitte erneut versuchen.';

  @override
  String get securityPinDigitsOnly => 'Nur Ziffern verwenden';

  @override
  String securityPinLength(int min, int max) {
    return '$min bis $max Ziffern';
  }

  @override
  String securityPasswordTooShort(int min) {
    return 'Mindestens $min Zeichen';
  }

  @override
  String get securityChangePin => 'PIN ändern';

  @override
  String get securityChangePassword => 'Passwort ändern';

  @override
  String get securityChangeDesc => 'Oder zwischen PIN und Passwort wechseln';

  @override
  String get securityLockNow => 'Jetzt sperren';

  @override
  String get securityLockOffDesc =>
      'Zum Öffnen der App eine PIN oder ein Passwort verlangen';

  @override
  String get securityLockTimeoutDesc =>
      'Wie lange die App im Hintergrund sein darf, bevor sie sperrt';

  @override
  String get securityConfirmIdentity => 'Bestätige, dass du es bist';

  @override
  String get securityCurrentPin => 'Aktuelle PIN';

  @override
  String get securityCurrentPassword => 'Aktuelles Passwort';

  @override
  String get securityDisableTitle => 'App-Sperre ausschalten?';

  @override
  String get securityDisableMessage =>
      'Dann kann jede Person mit Zugriff auf dieses Gerät die App öffnen und deine Finanzen sehen.';

  @override
  String get securityTurnOff => 'Ausschalten';

  @override
  String get securityTimeoutImmediately => 'Sofort';

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
  String get securityContentHidden => 'Inhalt verborgen';

  @override
  String get fieldAccount => 'Konto';

  @override
  String get fieldAmount => 'Betrag';

  @override
  String get fieldBalance => 'Saldo';

  @override
  String get fieldCategory => 'Kategorie';

  @override
  String get fieldDate => 'Datum';

  @override
  String get fieldNote => 'Notiz';

  @override
  String get fieldPayee => 'Empfänger';

  @override
  String get fieldStatus => 'Status';

  @override
  String get setAccentScheme => 'Akzentfarbe';

  @override
  String get setAmountColorStyle => 'Farben für Beträge';

  @override
  String get setAppLock => 'App-Sperre';

  @override
  String get setAutoExport => 'Automatischer Export';

  @override
  String get setAutoExportFolder => 'Exportordner';

  @override
  String get setAutoExportKeep => 'Letzte Exporte behalten';

  @override
  String get setBlockScreenshots => 'Screenshots blockieren';

  @override
  String get setBlockScreenshotsDesc => 'Nur Android';

  @override
  String get setBudgetMode => 'Budgetmodus';

  @override
  String get setCalculatorKeypad => 'Rechner-Tastatur';

  @override
  String get setConfirmDelete => 'Vor dem Löschen bestätigen';

  @override
  String get setCsvDateFormat => 'CSV-Datumsformat';

  @override
  String get setCsvDecimalSeparator => 'CSV-Dezimaltrennzeichen';

  @override
  String get setCsvDelimiter => 'CSV-Trennzeichen';

  @override
  String get setCsvEncoding => 'CSV-Zeichenkodierung';

  @override
  String get setCustomAccent => 'Eigene Akzentfarbe';

  @override
  String get setDashboardPeriod => 'Zeitraum im Dashboard';

  @override
  String get setDashboardWidgets => 'Dashboard-Widgets';

  @override
  String get setDateFormat => 'Datumsformat';

  @override
  String get setDefaultAccount => 'Standardkonto';

  @override
  String get setDefaultCategorySet => 'Standardkategorien';

  @override
  String get setDefaultDate => 'Standarddatum';

  @override
  String get setDefaultFilter => 'Standardfilter';

  @override
  String get setDefaultPostingMode => 'Standard-Buchungsmodus';

  @override
  String get setDefaultReturn => 'Standardrendite';

  @override
  String get setDefaultReturnDesc => 'Pro Jahr, für Konten ohne eigenen Wert';

  @override
  String get setDefaultRollover => 'Standard-Übertrag';

  @override
  String get setDefaultType => 'Standardtyp';

  @override
  String get setDensity => 'Dichte';

  @override
  String get setDeviceName => 'Gerätename';

  @override
  String get setDynamicColor => 'Dynamische Farben';

  @override
  String get setDynamicColorDesc =>
      'Systemakzentfarbe verwenden (Material You)';

  @override
  String get setExcludedAccounts => 'Ausgeschlossene Konten';

  @override
  String get setExcludedCategories => 'Ausgeschlossene Kategorien';

  @override
  String get setExcludedTags => 'Ausgeschlossene Tags';

  @override
  String get setFieldOrder => 'Feldreihenfolge beim Erfassen';

  @override
  String get setFirstDayOfWeek => 'Erster Wochentag';

  @override
  String get setFiscalYearStart => 'Geschäftsjahr beginnt im Monat';

  @override
  String get setFiscalYearStartDesc => '1 = Januar';

  @override
  String get setFormatLocale => 'Zahlen- & Datumsformat';

  @override
  String get setFormatLocaleDesc =>
      'Region für die Formatierung von Zahlen und Daten';

  @override
  String get setGrouping => 'Gruppierung';

  @override
  String get setHideAmounts => 'Beträge verbergen';

  @override
  String get setHideAmountsDesc => 'Beträge unscharf, bis sie angetippt werden';

  @override
  String get setHideInAppSwitcher => 'Inhalt im App-Umschalter verbergen';

  @override
  String get setHighContrast => 'Hoher Kontrast';

  @override
  String get setHolidayCountry => 'Feiertagskalender';

  @override
  String get setHolidayRegion => 'Bundesland';

  @override
  String get setHorizonMonths => 'Prognosezeitraum (Monate)';

  @override
  String get setImportProfiles => 'Importprofile & Verlauf';

  @override
  String get setIncludePending => 'Ausstehende einbeziehen';

  @override
  String get setIncludePlanned => 'Geplante einbeziehen';

  @override
  String get setInflation => 'Inflationsrate';

  @override
  String get setLanguage => 'Sprache';

  @override
  String get setLockMethod => 'Entsperrmethode';

  @override
  String get setLockOnStart => 'Beim Start sperren';

  @override
  String get setLockTimeout => 'Sperren nach (im Hintergrund)';

  @override
  String get setLowBalanceThreshold => 'Schwelle für niedrigen Kontostand';

  @override
  String get setManageCategories => 'Kategorien verwalten';

  @override
  String get setManageCustomFields => 'Eigene Felder verwalten';

  @override
  String get setManageTags => 'Tags verwalten';

  @override
  String get setModAttachments => 'Anhänge';

  @override
  String get setModBudgets => 'Budgets';

  @override
  String get setModCustomFields => 'Eigene Felder';

  @override
  String get setNavTabs => 'Navigationsleiste';

  @override
  String get setNavTabsDesc => 'Tabs auswählen und sortieren';

  @override
  String get setNotificationTime => 'Uhrzeit der Benachrichtigung';

  @override
  String get setNotifyBills => 'Bei Rechnungen benachrichtigen';

  @override
  String get setNotifyBudget => 'Bei Budgets benachrichtigen';

  @override
  String get setNotifyIncome => 'Bei Einnahmen benachrichtigen';

  @override
  String get setNotifyLowBalance => 'Bei niedrigem Kontostand benachrichtigen';

  @override
  String get setOnboardingDone => 'Einrichtung abgeschlossen';

  @override
  String get setOptAmber => 'Bernstein';

  @override
  String get setOptAutoPost => 'Automatisch buchen';

  @override
  String get setOptBiWeekly => 'Alle zwei Wochen';

  @override
  String get setOptBiometric => 'Biometrie';

  @override
  String get setOptBlue => 'Blau';

  @override
  String get setOptBudgetPeriod => 'Budgetzeitraum';

  @override
  String get setOptCalendarMonth => 'Kalendermonat';

  @override
  String get setOptColorCoded => 'Farbig';

  @override
  String get setOptComfortable => 'Komfortabel';

  @override
  String get setOptComma => 'Komma';

  @override
  String get setOptCompact => 'Kompakt';

  @override
  String get setOptCustom => 'Eigene';

  @override
  String get setOptDaily => 'Täglich';

  @override
  String get setOptDark => 'Dunkel';

  @override
  String get setOptDay => 'Tag';

  @override
  String get setOptEnvelope => 'Umschlag (nullbasiert)';

  @override
  String get setOptFromBudget => 'Aus dem Budget';

  @override
  String get setOptFromLanguage => 'Aus der Sprache';

  @override
  String get setOptLargestFirst => 'Größte zuerst';

  @override
  String get setOptLastMonth => 'Letzter Monat';

  @override
  String get setOptLastUsed => 'Zuletzt verwendet';

  @override
  String get setOptLastYear => 'Letztes Jahr';

  @override
  String get setOptLight => 'Hell';

  @override
  String get setOptLocaleDefault => 'Standard der Region';

  @override
  String get setOptMonday => 'Montag';

  @override
  String get setOptMonth => 'Monat';

  @override
  String get setOptMonthly => 'Monatlich';

  @override
  String get setOptNationwide => 'Nur bundesweit';

  @override
  String get setOptNeutral => 'Neutral';

  @override
  String get setOptNewestFirst => 'Neueste zuerst';

  @override
  String get setOptNextBusinessDay => 'Nächster Werktag';

  @override
  String get setOptNoRollover => 'Kein Übertrag';

  @override
  String get setOptNoShift => 'Nicht verschieben';

  @override
  String get setOptOff => 'Aus';

  @override
  String get setOptOldestFirst => 'Älteste zuerst';

  @override
  String get setOptPassword => 'Passwort';

  @override
  String get setOptPoint => 'Punkt';

  @override
  String get setOptPreviousBusinessDay => 'Vorheriger Werktag';

  @override
  String get setOptQuarterly => 'Vierteljährlich';

  @override
  String get setOptRemindConfirm => 'Erinnern & bestätigen';

  @override
  String get setOptRolloverBoth => 'Rest und Überzug';

  @override
  String get setOptRolloverLeftover => 'Rest übertragen';

  @override
  String get setOptRolloverOverspent => 'Überzug übertragen';

  @override
  String get setOptRose => 'Rosé';

  @override
  String get setOptSaturday => 'Samstag';

  @override
  String get setOptSemicolon => 'Semikolon';

  @override
  String get setOptSignOnly => 'Nur +/−';

  @override
  String get setOptSlate => 'Schiefer';

  @override
  String get setOptSmallestFirst => 'Kleinste zuerst';

  @override
  String get setOptSpruce => 'Fichte';

  @override
  String get setOptSunday => 'Sonntag';

  @override
  String get setOptSystem => 'System';

  @override
  String get setOptThisMonth => 'Dieser Monat';

  @override
  String get setOptThisYear => 'Dieses Jahr';

  @override
  String get setOptToday => 'Heute';

  @override
  String get setOptTracking => 'Verfolgen (Limits)';

  @override
  String get setOptViolet => 'Violett';

  @override
  String get setOptWeek => 'Woche';

  @override
  String get setOptWeekly => 'Wöchentlich';

  @override
  String get setOptYearToDate => 'Seit Jahresbeginn';

  @override
  String get setOptYearly => 'Jährlich';

  @override
  String get setPayeeSuggestions => 'Empfängervorschläge';

  @override
  String get setPayeeSuggestionsDesc =>
      'Kategorie und Konto aus dem Verlauf lernen';

  @override
  String get setPeriodType => 'Zeitraum';

  @override
  String get setPrivacyOnStart => 'Privatsphäre-Modus beim Start';

  @override
  String get setProjectionYears => 'Projektionsjahre';

  @override
  String get setQuietHoursEnd => 'Ruhezeit endet';

  @override
  String get setQuietHoursStart => 'Ruhezeit beginnt';

  @override
  String get setRealValues => 'Realwerte anzeigen';

  @override
  String get setRealValuesDesc => 'Projektionen inflationsbereinigt anzeigen';

  @override
  String get setRecentCategories => 'Angezeigte letzte Kategorien';

  @override
  String get setReminderLeadDays => 'Tage vorher erinnern';

  @override
  String get setReportPeriod => 'Standardzeitraum';

  @override
  String get setRequiredFields => 'Pflichtfelder';

  @override
  String get setRunningBalance => 'Laufender Saldo';

  @override
  String get setRunningBalanceDesc => 'Saldo nach jeder Buchung anzeigen';

  @override
  String get setSalaryBased => 'Mit dem Gehaltseingang beginnen';

  @override
  String get setSalaryBasedDesc =>
      'Der Zeitraum beginnt mit dem Eingang der gewählten Einnahme';

  @override
  String get setSalaryRule => 'Gehaltseingang';

  @override
  String get setSecAppearance => 'Darstellung';

  @override
  String get setSecBudgets => 'Budgets';

  @override
  String get setSecCategories => 'Kategorien & Tags';

  @override
  String get setSecDashboard => 'Dashboard';

  @override
  String get setSecData => 'Daten';

  @override
  String get setSecEntry => 'Erfassung';

  @override
  String get setSecForecast => 'Prognose & Projektion';

  @override
  String get setSecGeneral => 'Allgemein';

  @override
  String get setSecImportExport => 'Import / Export';

  @override
  String get setSecNavigation => 'Navigation & Module';

  @override
  String get setSecPrivacy => 'Privatsphäre';

  @override
  String get setSecRecurring => 'Wiederkehrend & Erinnerungen';

  @override
  String get setSecSecurity => 'Sicherheit';

  @override
  String get setShowCents => 'Cent anzeigen';

  @override
  String get setSignStyle => 'Negative Beträge';

  @override
  String get setSort => 'Sortierung';

  @override
  String get setStartDay => 'Starttag im Monat';

  @override
  String get setStartDayDesc => '0 = letzter Tag des Monats';

  @override
  String get setStartScreen => 'Startbildschirm';

  @override
  String get setStorageLocation => 'Speicherort';

  @override
  String get setTextScale => 'Textgröße';

  @override
  String get setThemeMode => 'Design';

  @override
  String get setTombstoneDays => 'Gelöschte Einträge behalten (Tage)';

  @override
  String get setTombstoneDaysDesc =>
      'Wird später für die Synchronisierung benötigt';

  @override
  String get setUpcomingDays => 'Zeitraum für anstehende Rechnungen (Tage)';

  @override
  String get setVariableMethod => 'Schätzung variabler Ausgaben';

  @override
  String get setVisibleColumns => 'Sichtbare Spalten';

  @override
  String get setWarnThreshold => 'Warnschwelle';

  @override
  String get setWeekendShift => 'Verschiebung an Wochenenden & Feiertagen';

  @override
  String setModuleEnabled(String module) {
    return '$module aktivieren';
  }

  @override
  String setOptMean(int n) {
    return 'Durchschnitt der letzten $n Monate';
  }

  @override
  String setOptMedian(int n) {
    return 'Median der letzten $n Monate';
  }

  @override
  String setOptLastNMonths(int n) {
    return 'Letzte $n Monate';
  }

  @override
  String get setSettingsTitle => 'Einstellungen';

  @override
  String get settingsUiSearchHint => 'Einstellungen durchsuchen';

  @override
  String settingsUiNoResults(String query) {
    return 'Keine Einstellung passt zu „$query“';
  }

  @override
  String get settingsUiClear => 'Leeren';

  @override
  String get settingsUiSecAbout => 'Über die App';

  @override
  String settingsUiAboutSummary(String version) {
    return 'Version $version';
  }

  @override
  String get settingsUiAboutVersion => 'Version';

  @override
  String get settingsUiAboutLicenses => 'Open-Source-Lizenzen';

  @override
  String get settingsUiAboutPrivacy =>
      'Alle Daten bleiben auf diesem Gerät. Kein Konto, keine Telemetrie.';

  @override
  String get settingsUiAboutEncryption => 'Datenbankverschlüsselung';

  @override
  String get settingsUiAboutEncryptionOn =>
      'An (SQLite3 Multiple Ciphers, Schlüssel im Schlüsselspeicher des Systems)';

  @override
  String get settingsUiAboutEncryptionOff =>
      'Aus: Beim Anlegen der Datenbank war kein sicherer Schlüsselspeicher verfügbar';

  @override
  String get settingsUiAboutEncryptionUnavailable =>
      'Auf dieser Plattform nicht verfügbar';

  @override
  String get settingsUiAmountsHidden => 'Beträge verborgen';

  @override
  String get settingsUiAmountsVisible => 'Beträge sichtbar';

  @override
  String settingsUiTabsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tabs',
      one: '1 Tab',
    );
    return '$_temp0';
  }

  @override
  String settingsUiDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage vorher',
      one: '1 Tag vorher',
      zero: 'Am selben Tag',
    );
    return '$_temp0';
  }

  @override
  String settingsUiMonthsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Monate',
      one: '1 Monat',
    );
    return '$_temp0';
  }

  @override
  String get settingsUiModuleOff => 'Modul aus';

  @override
  String settingsUiModuleOffNotice(String module) {
    return 'Das Modul $module ist ausgeschaltet.';
  }

  @override
  String get settingsUiTurnOn => 'Einschalten';

  @override
  String get settingsUiDataSummary => 'Speicherort, Statistik, Zurücksetzen';

  @override
  String get settingsUiResetSection => 'Bereich zurücksetzen';

  @override
  String settingsUiResetSectionTitle(String section) {
    return '„$section“ zurücksetzen?';
  }

  @override
  String get settingsUiResetSectionMessage =>
      'Alle Einstellungen in diesem Bereich werden auf die Standardwerte zurückgesetzt.';

  @override
  String get settingsUiResetDone => 'Bereich zurückgesetzt';

  @override
  String get settingsUiModulesTitle => 'Module';

  @override
  String get settingsUiModulesDesc =>
      'Ausgeschaltete Module verschwinden aus Navigation und Einstellungen. Ihre Daten bleiben erhalten.';

  @override
  String settingsUiNavTabsHint(int min, int max) {
    return '$min bis $max Tabs, „Mehr“ steht immer am Ende';
  }

  @override
  String get settingsUiNavTabsRecommend =>
      'Tipp: Behalte Start oder Buchungen in der Leiste.';

  @override
  String get settingsUiNavTabModuleOff =>
      'Ausgeblendet, solange das Modul aus ist';

  @override
  String get settingsUiNavMoreAlways => 'Immer sichtbar, immer am Ende';

  @override
  String get settingsUiDragHandle => 'Zum Sortieren ziehen';

  @override
  String get settingsUiMoveUp => 'Nach oben';

  @override
  String get settingsUiMoveDown => 'Nach unten';

  @override
  String get settingsUiNotSet => 'Nicht festgelegt';

  @override
  String settingsUiAndMore(int count) {
    return '+$count weitere';
  }

  @override
  String get settingsUiLastDay => 'Letzter Tag';

  @override
  String get settingsUiDecrease => 'Verringern';

  @override
  String get settingsUiIncrease => 'Erhöhen';

  @override
  String get settingsUiTapToType => 'Doppeltippen, um einen Wert einzugeben';

  @override
  String get settingsUiInvalidNumber => 'Zahl eingeben';

  @override
  String get settingsUiInvalidValue => 'Dieser Wert ist nicht zulässig';

  @override
  String settingsUiOutOfRange(int min, int max) {
    return 'Wert von $min bis $max eingeben';
  }

  @override
  String settingsUiOutOfRangeText(String min, String max) {
    return 'Von $min bis $max';
  }

  @override
  String get settingsUiPresets => 'Vorlagen';

  @override
  String get settingsUiCustomColor => 'Eigene Farbe';

  @override
  String get settingsUiHue => 'Farbton';

  @override
  String get settingsUiSaturation => 'Sättigung';

  @override
  String get settingsUiLightness => 'Helligkeit';

  @override
  String get settingsUiHex => 'HEX';

  @override
  String get settingsUiInvalidHex => 'Farbe wie #1F5A53 eingeben';

  @override
  String get settingsUiNoTags => 'Noch keine Tags';

  @override
  String get settingsUiPrivacyNow => 'Beträge jetzt verbergen';

  @override
  String get settingsUiPrivacyNowDesc => 'Privatsphäre-Modus für diese Sitzung';

  @override
  String get settingsUiStats => 'Datenbankstatistik';

  @override
  String get settingsUiStatRecurring => 'Wiederkehrende Buchungen';

  @override
  String get settingsUiStatImports => 'Importe';

  @override
  String get settingsUiStatChangeLog => 'Einträge im Änderungsprotokoll';

  @override
  String get settingsUiStatDbSize => 'Datenbankgröße';

  @override
  String get settingsUiRefresh => 'Aktualisieren';

  @override
  String get settingsUiRebuildIndex => 'Suchindex neu aufbauen';

  @override
  String get settingsUiRebuildIndexDesc =>
      'Behebt fehlende oder veraltete Suchergebnisse';

  @override
  String get settingsUiRebuildDone => 'Suchindex neu aufgebaut';

  @override
  String get settingsUiRerunRules => 'Regeln erneut anwenden';

  @override
  String get settingsUiRerunRulesDesc =>
      'Kategorisierungsregeln auf vorhandene Buchungen anwenden';

  @override
  String get settingsUiRerunRulesAll => 'Alle Buchungen neu bewerten';

  @override
  String get settingsUiRerunRulesAllDesc =>
      'Regelwerte ersetzen auch vorhandene Kategorien, nicht nur leere';

  @override
  String settingsUiRerunRulesDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Buchungen geändert',
      one: '1 Buchung geändert',
      zero: 'Keine Buchung geändert',
    );
    return '$_temp0';
  }

  @override
  String get settingsUiRun => 'Ausführen';

  @override
  String get settingsUiResetApp => 'App zurücksetzen';

  @override
  String get settingsUiResetAppDesc =>
      'Alle Daten auf diesem Gerät löschen und neu beginnen';

  @override
  String get settingsUiResetAppTitle => 'Alle Daten löschen?';

  @override
  String settingsUiResetAppMessage(String word) {
    return 'Dadurch werden alle Konten, Buchungen, Budgets, Regeln und Einstellungen auf diesem Gerät sowie die App-Sperre gelöscht. Gib zur Bestätigung $word ein.';
  }

  @override
  String get settingsUiResetAppWord => 'LÖSCHEN';

  @override
  String settingsUiTypeToConfirm(String word) {
    return '$word eingeben';
  }

  @override
  String get settingsUiResetAppConfirm => 'Alles löschen';

  @override
  String get settingsUiStorageDefault => 'Standardordner der App';

  @override
  String get settingsUiStorageMoveTitle => 'Speicherort ändern?';

  @override
  String settingsUiStorageMoveMessage(String path) {
    return 'Die aktuelle Datenbank wird nach $path kopiert und nach dem nächsten Neustart von dort verwendet. Die alte Datei bleibt erhalten.';
  }

  @override
  String settingsUiStorageExisting(String path) {
    return '$path enthält bereits eine Datenbank. Sie wird nach dem nächsten Neustart verwendet; es wird nichts kopiert. Sie muss mit dieser Installation erstellt worden sein, sonst lässt sie sich nicht öffnen.';
  }

  @override
  String get settingsUiStorageCopy => 'Kopieren und wechseln';

  @override
  String get settingsUiStorageUseExisting => 'Diese Datenbank verwenden';

  @override
  String get settingsUiStorageRestart =>
      'Starte die App neu, um den neuen Speicherort zu verwenden.';

  @override
  String get settingsUiStorageResetDefault => 'Standardordner verwenden';

  @override
  String get settingsUiStorageResetMessage =>
      'Nach dem nächsten Neustart verwendet die App wieder die Datenbank im Standardordner. Daten im eigenen Ordner werden nicht zurückkopiert.';

  @override
  String get settingsUiStatDeleted =>
      'Gelöschte Einträge (für Sync aufbewahrt)';

  @override
  String get settingsUiPurge => 'Gelöschte Einträge bereinigen';

  @override
  String settingsUiPurgeDesc(int days) {
    return 'Einträge entfernen, die vor mehr als $days Tagen gelöscht wurden';
  }

  @override
  String settingsUiPurgeMessage(int days) {
    return 'Entfernt Einträge endgültig, die vor mehr als $days Tagen gelöscht wurden. Sie lassen sich danach nicht mehr wiederherstellen oder synchronisieren.';
  }

  @override
  String get settingsUiPurgeConfirm => 'Bereinigen';

  @override
  String settingsUiPurgeDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge entfernt',
      one: '1 Eintrag entfernt',
      zero: 'Nichts zu bereinigen',
    );
    return '$_temp0';
  }

  @override
  String get txnSearchHint => 'Empfänger, Notiz, Kategorie suchen';

  @override
  String get txnSearchLabel => 'Buchungen durchsuchen';

  @override
  String get txnSearchHintWide => 'Empfänger, Notiz, Tag, Kategorie';

  @override
  String get txnSelectMultiple => 'Mehrere auswählen';

  @override
  String get txnNew => 'Neu';

  @override
  String get txnCtrl => 'Strg';

  @override
  String txnEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String get txnIn => 'Ein';

  @override
  String get txnOut => 'Aus';

  @override
  String get txnToday => 'Heute';

  @override
  String get txnYesterday => 'Gestern';

  @override
  String txnTodayDate(String date) {
    return 'Heute, $date';
  }

  @override
  String txnYesterdayDate(String date) {
    return 'Gestern, $date';
  }

  @override
  String txnGroupToday(String date) {
    return 'Heute · $date';
  }

  @override
  String txnGroupYesterday(String date) {
    return 'Gestern · $date';
  }

  @override
  String txnTransferTo(String account) {
    return 'An $account';
  }

  @override
  String txnTransferFrom(String account) {
    return 'Von $account';
  }

  @override
  String txnTransferFromSub(String account) {
    return 'Umbuchung · von $account';
  }

  @override
  String txnTransferToSub(String account) {
    return 'Umbuchung · an $account';
  }

  @override
  String txnSplitCount(int count) {
    return 'Aufgeteilt · $count';
  }

  @override
  String get txnNoPayee => 'Ohne Empfänger';

  @override
  String get txnUncategorized => 'Ohne Kategorie';

  @override
  String get txnUnknownAccount => 'Unbekanntes Konto';

  @override
  String get txnHasReceipt => 'Mit Beleg';

  @override
  String get txnRecurring => 'Wiederkehrend';

  @override
  String txnBalanceShort(String amount) {
    return 'Saldo $amount';
  }

  @override
  String get txnEmpty =>
      'Noch keine Buchungen. Lege die erste mit der +‑Taste an.';

  @override
  String get txnEmptyFiltered => 'Keine Buchungen passen zu diesen Filtern.';

  @override
  String get txnClearFilters => 'Filter zurücksetzen';

  @override
  String get txnFilters => 'Filter';

  @override
  String get txnFilterAllDates => 'Alle Zeiträume';

  @override
  String get txnFilterType => 'Art';

  @override
  String get txnFilterTag => 'Tag';

  @override
  String get txnFilterCustomField => 'Eigenes Feld';

  @override
  String txnChipCount(String label, int count) {
    return '$label · $count';
  }

  @override
  String get txnSaveFilter => 'Filter speichern';

  @override
  String get txnPresetThisMonth => 'Dieser Monat';

  @override
  String get txnPresetLastMonth => 'Letzter Monat';

  @override
  String get txnPresetLast30 => 'Letzte 30 Tage';

  @override
  String get txnPresetLast90 => 'Letzte 90 Tage';

  @override
  String get txnPresetThisYear => 'Dieses Jahr';

  @override
  String get txnPresetLastYear => 'Letztes Jahr';

  @override
  String get txnPresetCustom => 'Eigener Zeitraum …';

  @override
  String get txnAmountMin => 'Mindestens';

  @override
  String get txnAmountMax => 'Höchstens';

  @override
  String get txnAmountHint => 'Verglichen wird der Betrag ohne Vorzeichen.';

  @override
  String txnAmountAtLeast(String amount) {
    return '≥ $amount';
  }

  @override
  String txnAmountAtMost(String amount) {
    return '≤ $amount';
  }

  @override
  String get txnApply => 'Anwenden';

  @override
  String get txnChooseCategories => 'Kategorien wählen';

  @override
  String get txnCustomFieldAny => 'Hat einen Wert';

  @override
  String get txnCustomFieldEquals => 'Ist';

  @override
  String get txnCustomFieldContains => 'Enthält';

  @override
  String get txnCustomFieldIncludes => 'Enthält Option';

  @override
  String get txnCustomFieldValue => 'Wert';

  @override
  String get txnCustomFieldAdd => 'Bedingung hinzufügen';

  @override
  String get txnCustomFieldChoose => 'Feld';

  @override
  String get txnCustomFieldNone => 'Noch keine eigenen Felder für Buchungen.';

  @override
  String get txnSavedFilters => 'Gespeicherte Filter';

  @override
  String get txnAllTransactions => 'Alle Buchungen';

  @override
  String get txnFilterName => 'Name';

  @override
  String get txnFilterSaved => 'Filter gespeichert';

  @override
  String get txnFilterUpdated => 'Filter aktualisiert';

  @override
  String get txnUpdateFilter => 'Mit aktuellem Filter aktualisieren';

  @override
  String get txnRename => 'Umbenennen';

  @override
  String get txnSetDefault => 'Als Standard verwenden';

  @override
  String get txnUnsetDefault => 'Nicht mehr als Standard';

  @override
  String get txnIsDefault => 'Standard';

  @override
  String get txnFilterDeleted => 'Filter gelöscht';

  @override
  String get txnNoSavedFilters =>
      'Noch keine gespeicherten Filter. Setze in der Buchungsliste Filter und tippe auf „Filter speichern“.';

  @override
  String get txnNoDefaultFilter => 'Kein Standardfilter';

  @override
  String get txnNameRequired => 'Bitte einen Namen eingeben';

  @override
  String get txnViewOptions => 'Ansicht';

  @override
  String get txnGroupingOffHint =>
      'Gruppiert wird nur bei Sortierung nach Datum.';

  @override
  String get txnRunningBalanceHint =>
      'Der laufende Saldo erscheint, wenn die Liste auf ein Konto gefiltert und nach Datum sortiert ist.';

  @override
  String get txnChooseAccountAction => 'Konto wählen';

  @override
  String txnSelectedCount(int count) {
    return '$count ausgewählt';
  }

  @override
  String get txnSelectAll => 'Alle auswählen';

  @override
  String get txnClearSelection => 'Auswahl aufheben';

  @override
  String get txnSetCategory => 'Kategorie setzen';

  @override
  String get txnSetStatus => 'Status setzen';

  @override
  String get txnSetDate => 'Datum setzen';

  @override
  String get txnSetAccount => 'In Konto verschieben';

  @override
  String get txnAddTags => 'Tags hinzufügen';

  @override
  String txnBulkUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Buchungen geändert',
      one: '1 Buchung geändert',
    );
    return '$_temp0';
  }

  @override
  String txnDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Buchungen gelöscht',
      one: 'Buchung gelöscht',
    );
    return '$_temp0';
  }

  @override
  String txnDeleteConfirmTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Buchungen löschen?',
      one: 'Diese Buchung löschen?',
    );
    return '$_temp0';
  }

  @override
  String get txnDeleteConfirmBody =>
      'Du kannst das direkt danach rückgängig machen.';

  @override
  String get txnDuplicate => 'Duplizieren';

  @override
  String get txnDuplicated => 'Buchung dupliziert';

  @override
  String get txnMarkCleared => 'Als gebucht markieren';

  @override
  String get txnMarkPending => 'Als ausstehend markieren';

  @override
  String get txnStatusChanged => 'Status geändert';

  @override
  String get txnSaveAsTemplate => 'Als Vorlage speichern';

  @override
  String get txnTemplateSaved => 'Vorlage gespeichert';

  @override
  String get txnOpen => 'Öffnen';

  @override
  String get txnSelect => 'Auswählen';

  @override
  String get txnMoreActions => 'Weitere Aktionen';

  @override
  String get txnDetailTitle => 'Buchung';

  @override
  String get txnEditTransaction => 'Buchung bearbeiten';

  @override
  String get txnCloseDetail => 'Details schließen';

  @override
  String get txnNotFound => 'Diese Buchung gibt es nicht mehr.';

  @override
  String get txnSplit => 'Aufteilung';

  @override
  String get txnCustomFields => 'Eigene Felder';

  @override
  String get txnAttachments => 'Anhänge';

  @override
  String txnAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Anhänge · $count Dateien',
      one: 'Anhang · 1 Datei',
    );
    return '$_temp0';
  }

  @override
  String get txnAddAttachment => 'Anhang hinzufügen';

  @override
  String get txnAttachReceipt => 'Beleg anhängen';

  @override
  String txnRemoveAttachment(String name) {
    return 'Anhang $name entfernen';
  }

  @override
  String get txnAttachmentUnavailable =>
      'Die Datei ist auf diesem Gerät nicht verfügbar.';

  @override
  String get txnAttachmentPending => 'Wird mit der Buchung gespeichert';

  @override
  String get txnShare => 'Teilen';

  @override
  String get txnOrigin => 'Herkunft';

  @override
  String txnOriginRecurring(String name) {
    return 'Wiederkehrend: $name';
  }

  @override
  String txnOriginImport(String file) {
    return 'Importiert aus $file';
  }

  @override
  String get txnOriginManual => 'Manuell erfasst';

  @override
  String get txnValueDate => 'Wertstellung';

  @override
  String get txnNewTransaction => 'Neue Buchung';

  @override
  String get txnNewTemplate => 'Neue Vorlage';

  @override
  String get txnEditTemplate => 'Vorlage bearbeiten';

  @override
  String get txnSaveExpense => 'Ausgabe speichern';

  @override
  String get txnSaveIncome => 'Einnahme speichern';

  @override
  String get txnSaveTransfer => 'Umbuchung speichern';

  @override
  String get txnSaveChanges => 'Änderungen speichern';

  @override
  String get txnSaveTemplate => 'Vorlage speichern';

  @override
  String get txnSplitAction => 'Auf Kategorien aufteilen';

  @override
  String get txnRecentCategories => 'Zuletzt verwendet';

  @override
  String get txnFromAccount => 'Von';

  @override
  String get txnToAccount => 'An';

  @override
  String get txnChooseAccount => 'Konto wählen';

  @override
  String get txnChooseCategory => 'Kategorie wählen';

  @override
  String get txnKeypad => 'Betragstastatur';

  @override
  String get txnDecimalSeparator => 'Dezimaltrennzeichen';

  @override
  String get txnDeleteDigit => 'Ziffer löschen';

  @override
  String get txnPlus => 'Plus';

  @override
  String get txnMinus => 'Minus';

  @override
  String get txnTimes => 'Mal';

  @override
  String get txnDivide => 'Geteilt durch';

  @override
  String txnAmountPreview(String amount) {
    return '= $amount';
  }

  @override
  String get txnErrAmount => 'Bitte einen Betrag eingeben';

  @override
  String get txnErrAmountInvalid => 'Diese Rechnung ist ungültig';

  @override
  String get txnErrDivZero => 'Division durch null';

  @override
  String get txnErrTooLarge => 'Dieser Betrag ist zu groß';

  @override
  String get txnErrRequired => 'Pflichtfeld';

  @override
  String get txnErrSameAccount => 'Bitte zwei verschiedene Konten wählen';

  @override
  String get txnErrSplit => 'Die Aufteilung muss die Gesamtsumme ergeben';

  @override
  String get txnErrNoAccount =>
      'Lege zuerst ein Konto an, um Buchungen zu erfassen.';

  @override
  String get txnErrCheckFields => 'Bitte prüfe die markierten Felder.';

  @override
  String get txnCreateAccount => 'Konto anlegen';

  @override
  String get txnSavedExpense => 'Ausgabe gespeichert';

  @override
  String get txnSavedIncome => 'Einnahme gespeichert';

  @override
  String get txnSavedTransfer => 'Umbuchung gespeichert';

  @override
  String get txnChangesSaved => 'Änderungen gespeichert';

  @override
  String txnSaveFailed(String message) {
    return 'Speichern fehlgeschlagen: $message';
  }

  @override
  String get txnAddSplit => 'Zeile hinzufügen';

  @override
  String txnRemaining(String amount) {
    return 'Offen $amount';
  }

  @override
  String txnOverAssigned(String amount) {
    return 'Zu viel: $amount';
  }

  @override
  String get txnFullyAssigned => 'Vollständig verteilt';

  @override
  String get txnRemoveSplit => 'Zeile entfernen';

  @override
  String txnSplitLineCategory(int n) {
    return 'Kategorie von Zeile $n';
  }

  @override
  String txnSplitLineAmount(int n) {
    return 'Betrag von Zeile $n';
  }

  @override
  String get txnAssignRemaining => 'Rest zuweisen';

  @override
  String get txnStopSplit => 'Aufteilung entfernen';

  @override
  String get txnAddTag => 'Tag hinzufügen';

  @override
  String txnRemoveTag(String name) {
    return 'Tag $name entfernen';
  }

  @override
  String txnCreateTag(String name) {
    return '„$name“ anlegen';
  }

  @override
  String get txnSearchTags => 'Tag suchen oder anlegen';

  @override
  String get txnMoreDetails => 'Weitere Angaben';

  @override
  String txnUseTemplate(String name) {
    return 'Vorlage $name verwenden';
  }

  @override
  String get txnTemplatesEmpty =>
      'Noch keine Vorlagen. Speichere eine Buchung als Vorlage, um sie mit einem Tipp zu erfassen.';

  @override
  String get txnTemplateAddNow => 'Jetzt buchen';

  @override
  String txnTemplatePosted(String name) {
    return '$name gebucht';
  }

  @override
  String get txnTemplateName => 'Name der Vorlage';

  @override
  String get txnTemplateDeleted => 'Vorlage gelöscht';

  @override
  String get txnTemplateFillIn => 'In Schnelleingabe öffnen';

  @override
  String get txnTemplateInvalid =>
      'Diese Vorlage ist unvollständig. Bearbeite sie und wähle ein Konto.';

  @override
  String get txnPickDate => 'Datum wählen';

  @override
  String get txnClear => 'Leeren';

  @override
  String txnSum(String amount) {
    return 'Summe $amount';
  }

  @override
  String get txnKeyDelete => 'Entf';

  @override
  String get txnImportBatchChip => 'Aus einem Import';

  @override
  String get txnCreateRule => 'Regel erstellen';
}
