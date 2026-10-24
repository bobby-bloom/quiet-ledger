import 'package:personal_finance/features/import/domain/import_config.dart';
import 'package:personal_finance/features/import/domain/text_normalize.dart';

/// Header names (DE + EN) per target, as [headerKey]s. Order matters for
/// partial matches: more specific targets come first.
const headerSynonyms = <ColumnTarget, List<String>>{
  ColumnTarget.valueDate: [
    'valuta',
    'valutadatum',
    'wertstellung',
    'wertstellungsdatum',
    'wertstell',
    'valuedate',
  ],
  ColumnTarget.balance: [
    'saldo',
    'kontostand',
    'kontosaldo',
    'neuersaldo',
    'saldoeur',
    'bestand',
    'stand',
    'balance',
    'runningbalance',
    'accountbalance',
    'endingbalance',
  ],
  ColumnTarget.date: [
    'datum',
    'buchungstag',
    'buchungsdatum',
    'buchung',
    'belegdatum',
    'umsatzdatum',
    'transaktionsdatum',
    'zahlungsdatum',
    'wann',
    'date',
    'bookingdate',
    'transactiondate',
    'posted',
    'posteddate',
    'postingdate',
    'when',
    'day',
  ],
  ColumnTarget.amountType: [
    'sh',
    'sollhaben',
    'typ',
    'art',
    'buchungsart',
    'einnahmeausgabe',
    'ausgabeeinnahme',
    'type',
    'drcr',
    'crdr',
    'debitcredit',
    'creditdebit',
    'transactiontype',
    'direction',
  ],
  ColumnTarget.debit: [
    'soll',
    'ausgabe',
    'ausgaben',
    'belastung',
    'abgang',
    'abbuchung',
    'auszahlung',
    'betragsoll',
    'sollbetrag',
    'debit',
    'debits',
    'debitamount',
    'withdrawal',
    'withdrawals',
    'moneyout',
    'paidout',
    'out',
    'outflow',
    'spent',
  ],
  ColumnTarget.credit: [
    'haben',
    'einnahme',
    'einnahmen',
    'gutschrift',
    'zugang',
    'eingang',
    'einzahlung',
    'betraghaben',
    'habenbetrag',
    'credit',
    'credits',
    'creditamount',
    'deposit',
    'deposits',
    'moneyin',
    'paidin',
    'in',
    'inflow',
    'received',
  ],
  ColumnTarget.amount: [
    'betrag',
    'betrageur',
    'betragineur',
    'umsatz',
    'umsatzeur',
    'umsatzineur',
    'summe',
    'eur',
    'euro',
    'wert',
    'amount',
    'amounteur',
    'transactionamount',
    'value',
    'sum',
  ],
  ColumnTarget.subcategory: [
    'unterkategorie',
    'subkategorie',
    'detailkategorie',
    'untergruppe',
    'subcategory',
    'sub',
  ],
  ColumnTarget.category: [
    'kategorie',
    'hauptkategorie',
    'kategorien',
    'gruppe',
    'bereich',
    'kostenart',
    'ausgabenart',
    'category',
    'categories',
    'maincategory',
    'group',
  ],
  ColumnTarget.payee: [
    'empfaenger',
    'auftraggeber',
    'auftraggeberempfaenger',
    'empfaengerauftraggeber',
    'zahlungsempfaenger',
    'zahlungspflichtiger',
    'beguenstigter',
    'beguenstigterzahlungspflichtiger',
    'zahlungspflichtigerbeguenstigter',
    'name',
    'nameauftraggeberempfaenger',
    'geschaeft',
    'haendler',
    'laden',
    'wer',
    'was',
    'payee',
    'merchant',
    'recipient',
    'counterparty',
    'beneficiary',
    'who',
    'what',
    'shop',
    'store',
  ],
  ColumnTarget.note: [
    'verwendungszweck',
    'buchungstext',
    'beschreibung',
    'notiz',
    'notizen',
    'bemerkung',
    'bemerkungen',
    'kommentar',
    'text',
    'zweck',
    'info',
    'details',
    'memo',
    'note',
    'notes',
    'description',
    'reference',
    'purpose',
    'comment',
    'comments',
  ],
  ColumnTarget.account: [
    'konto',
    'kontoname',
    'bankkonto',
    'zahlungsmittel',
    'bezahltmit',
    'account',
    'accountname',
    'paidwith',
    'paymentmethod',
  ],
  ColumnTarget.tags: [
    'tags',
    'schlagworte',
    'schlagwoerter',
    'stichworte',
    'labels',
    'label',
    'markierung',
  ],
  ColumnTarget.status: ['status', 'state', 'gebucht', 'cleared', 'zustand'],
  ColumnTarget.ignore: [
    'waehrung',
    'whrg',
    'currency',
    'iban',
    'bic',
    'kontonummer',
    'blz',
    'glaeubigerid',
    'mandatsreferenz',
    'kundenreferenz',
    'nr',
    'lfdnr',
    'no',
    'id',
  ],
};

/// Raw header texts that are not words.
const _symbolHeaders = <String, ColumnTarget>{
  '+/-': ColumnTarget.amountType,
  '±': ColumnTarget.amountType,
  '+-': ColumnTarget.amountType,
  's/h': ColumnTarget.amountType,
  'cr/dr': ColumnTarget.amountType,
  'dr/cr': ColumnTarget.amountType,
  '€': ColumnTarget.amount,
};

/// The target a header label suggests, with a confidence: 3 = exact,
/// 2 = last word of a multi-row header, 1 = partial. Null when nothing
/// fits.
(ColumnTarget, int)? targetForHeader(String label) {
  final trimmed = label.trim().toLowerCase();
  if (trimmed.isEmpty) return null;
  final symbol = _symbolHeaders[trimmed];
  if (symbol != null) return (symbol, 3);
  final key = headerKey(label);
  if (key.isEmpty) return null;
  // "Soll (EUR)", "Betrag in €" → "soll", "betrag".
  final stripped = key.replaceFirst(RegExp(r'(in)?(eur|euro)$'), '');
  for (final k in {key, if (stripped.isNotEmpty) stripped}) {
    for (final e in headerSynonyms.entries) {
      if (e.value.contains(k)) return (e.key, 3);
    }
  }
  // Multi-row headers are joined with spaces: "Betrag Ausgabe" → "ausgabe".
  final words = label.trim().split(RegExp(r'\s+'));
  if (words.length > 1) {
    final last = headerKey(words.last);
    for (final e in headerSynonyms.entries) {
      if (e.value.contains(last)) return (e.key, 2);
    }
  }
  // Partial: the header contains a synonym of at least 5 letters
  // ("Buchungsdatum Bank" → date, "Verwendungszweck 2" → note).
  ColumnTarget? best;
  var bestLen = 0;
  for (final e in headerSynonyms.entries) {
    for (final s in e.value) {
      if (s.length >= 5 && s.length > bestLen && key.contains(s)) {
        best = e.key;
        bestLen = s.length;
      }
    }
  }
  return best == null ? null : (best, 1);
}

/// Whether [label] is a known header word for any target.
bool isKnownHeader(String label) => targetForHeader(label) != null;
