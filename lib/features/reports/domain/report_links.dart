import 'package:personal_finance/core/calendar/budget_period.dart';
import 'package:personal_finance/core/db/tables.dart';
import 'package:personal_finance/features/reports/domain/report_models.dart';

/// Value of the `category` query parameter for uncategorised transactions.
const uncategorizedParam = 'none';

String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Location of the transactions list showing what a report row is made of.
///
/// Query parameters (all optional; the transactions feature interprets
/// them):
/// * `from`, `to`: ISO dates `yyyy-MM-dd`, both **inclusive**.
/// * `type`: `expense` | `income`.
/// * `category`: comma-separated category ids, or `none` for
///   uncategorised. Roll-up rows pass the top-level category followed by
///   all its children.
/// * `payee`: payee text (case-insensitive exact match).
/// * `account`: comma-separated account ids.
/// * `tag`: comma-separated tag ids (any of).
/// * `field`, `fieldValue`: custom field id and value.
///
/// Example: `/transactions?from=2026-03-01&to=2026-03-31&type=expense&category=food,groceries,restaurants`.
String transactionsLocation({
  required DateRange range,
  ReportFilter? filter,
  CategoryKind? kind,
  String? categoryId,
  bool uncategorized = false,
  Iterable<String> childIds = const [],
  String? payee,
}) {
  final f = filter;
  final cf = f?.customField;
  final params = <String, String>{
    'from': _isoDay(range.start),
    'to': _isoDay(range.last),
    if (kind != null) 'type': kind.name,
    'category': ?(uncategorized
        ? uncategorizedParam
        : categoryId == null
        ? null
        : [categoryId, ...childIds].join(',')),
    if (payee != null && payee.isNotEmpty) 'payee': payee,
    if (f != null && f.accountIds.isNotEmpty)
      'account': (f.accountIds.toList()..sort()).join(','),
    if (f != null && f.tagIds.isNotEmpty)
      'tag': (f.tagIds.toList()..sort()).join(','),
    if (cf != null) 'field': cf.fieldId,
    if (cf != null)
      'fieldValue': cf.value is DateTime
          ? _isoDay(cf.value as DateTime)
          : '${cf.value}',
  };
  return Uri(path: '/transactions', queryParameters: params).toString();
}
