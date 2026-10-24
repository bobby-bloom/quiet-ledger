import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:personal_finance/core/db/database.dart';

// Generic, schema-driven row access for synced tables, shared by the sync
// engine and the backup bundle. Values here are *raw SQL values* as SQLite
// stores them: int (also for bool 0/1 and DateTime as unix seconds),
// String, double, Uint8List or null.
//
// These helpers bypass `SyncWriter` on purpose: they are used only to apply
// remote changes (which must not be re-logged as local changes), to restore
// a backup and for data maintenance. Feature code must keep using
// `SyncWriter`.

/// Sync metadata columns present on every synced table.
const syncColumnNames = {
  'id',
  'created_at',
  'updated_at',
  'deleted_at',
  'origin_device_id',
};

/// Thrown when a value cannot be converted to a column's SQL type.
class RawValueException implements Exception {
  RawValueException(this.table, this.column, this.value);
  final String table;
  final String column;
  final Object? value;

  @override
  String toString() =>
      'RawValueException: invalid value for $table.$column: $value';
}

/// Converts a JSON value (as written to `change_log.changed_fields` by
/// `SyncWriter`, or a raw SQL value) to the raw SQL value of [column].
///
/// Accepts: bool or 0/1 for bool columns; ISO-8601 strings, unix seconds or
/// DateTime for dateTime columns; base64 strings or bytes for blobs.
Object? toSqlValue(GeneratedColumn<Object> column, Object? value) {
  if (value == null) return null;
  final type = column.type;
  Never bad() => throw RawValueException(column.tableName, column.name, value);
  if (type == DriftSqlType.bool) {
    return switch (value) {
      final bool b => b ? 1 : 0,
      final num n => n.toInt() == 0 ? 0 : 1,
      'true' || '1' => 1,
      'false' || '0' => 0,
      _ => bad(),
    };
  }
  if (type == DriftSqlType.int || type == DriftSqlType.bigInt) {
    return switch (value) {
      final int i => i,
      final BigInt i => i.toInt(),
      final num n when n == n.truncate() => n.toInt(),
      final String s => int.tryParse(s) ?? bad(),
      _ => bad(),
    };
  }
  if (type == DriftSqlType.dateTime) {
    return switch (value) {
      final int i => i,
      final num n => n.toInt(),
      final DateTime d => d.millisecondsSinceEpoch ~/ 1000,
      final String s =>
        int.tryParse(s) ??
            (DateTime.tryParse(s)?.millisecondsSinceEpoch ?? bad()) ~/ 1000,
      _ => bad(),
    };
  }
  if (type == DriftSqlType.double) {
    return switch (value) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? bad(),
      _ => bad(),
    };
  }
  if (type == DriftSqlType.blob) {
    return switch (value) {
      final Uint8List b => b,
      final List<int> b => Uint8List.fromList(b),
      final String s => base64Decode(s),
      _ => bad(),
    };
  }
  return switch (value) {
    final String s => s,
    final num n => n.toString(),
    final bool b => b.toString(),
    _ => jsonEncode(value),
  };
}

/// Converts a raw SQL value to a JSON-safe value (blobs → base64).
Object? toJsonValue(Object? sqlValue) => switch (sqlValue) {
  final Uint8List b => base64Encode(b),
  final BigInt i => i.toInt(),
  _ => sqlValue,
};

/// Column lookup by SQL name.
GeneratedColumn<Object>? columnOf(
  TableInfo<Table, dynamic> table,
  String name,
) => table.columnsByName[name];

/// Reads raw rows of [table] (all columns). [where] is an SQL condition with
/// `?` placeholders bound to [args].
Future<List<Map<String, Object?>>> selectRawRows(
  AppDatabase db,
  TableInfo<Table, dynamic> table, {
  String? where,
  List<Object?> args = const [],
  String? orderBy,
}) async {
  final sql = StringBuffer('SELECT * FROM "${table.actualTableName}"');
  if (where != null) sql.write(' WHERE $where');
  if (orderBy != null) sql.write(' ORDER BY $orderBy');
  final rows = await db
      .customSelect(
        sql.toString(),
        variables: [for (final a in args) _variable(a)],
        readsFrom: {table},
      )
      .get();
  return [for (final r in rows) Map<String, Object?>.of(r.data)];
}

/// Reads one raw row by id (including soft-deleted rows).
Future<Map<String, Object?>?> selectRawRow(
  AppDatabase db,
  TableInfo<Table, dynamic> table,
  String id,
) async {
  final rows = await selectRawRows(db, table, where: 'id = ?', args: [id]);
  return rows.firstOrNull;
}

/// Inserts or replaces a full raw row. Unknown columns throw.
Future<void> upsertRawRow(
  AppDatabase db,
  TableInfo<Table, dynamic> table,
  Map<String, Object?> values,
) {
  _checkColumns(table, values.keys);
  final cols = values.keys.toList();
  final sql =
      'INSERT OR REPLACE INTO "${table.actualTableName}" '
      '(${cols.map((c) => '"$c"').join(', ')}) '
      'VALUES (${List.filled(cols.length, '?').join(', ')})';
  return db.customStatement(sql, [for (final c in cols) values[c]]);
}

/// Inserts many raw rows with the same [columns] in multi-row statements.
Future<void> insertRawRows(
  AppDatabase db,
  TableInfo<Table, dynamic> table,
  List<String> columns,
  List<List<Object?>> rows,
) async {
  if (rows.isEmpty) return;
  _checkColumns(table, columns);
  // SQLite's default limit is 32766 bound variables; stay well below.
  final perStatement = (900 ~/ columns.length).clamp(1, 500);
  final head =
      'INSERT INTO "${table.actualTableName}" '
      '(${columns.map((c) => '"$c"').join(', ')}) VALUES ';
  final tuple = '(${List.filled(columns.length, '?').join(', ')})';
  for (var i = 0; i < rows.length; i += perStatement) {
    final chunk = rows.sublist(i, (i + perStatement).clamp(0, rows.length));
    await db.customStatement(
      head + List.filled(chunk.length, tuple).join(', '),
      [for (final r in chunk) ...r],
    );
  }
}

/// Updates the given raw columns of row [id].
Future<void> updateRawRow(
  AppDatabase db,
  TableInfo<Table, dynamic> table,
  String id,
  Map<String, Object?> values,
) {
  if (values.isEmpty) return Future.value();
  _checkColumns(table, values.keys);
  final cols = values.keys.toList();
  final sql =
      'UPDATE "${table.actualTableName}" SET '
      '${cols.map((c) => '"$c" = ?').join(', ')} WHERE id = ?';
  return db.customStatement(sql, [for (final c in cols) values[c], id]);
}

void _checkColumns(TableInfo<Table, dynamic> table, Iterable<String> cols) {
  for (final c in cols) {
    if (!table.columnsByName.containsKey(c)) {
      throw ArgumentError.value(c, 'column', 'not in ${table.actualTableName}');
    }
  }
}

Variable<Object> _variable(Object? v) => switch (v) {
  null => const Variable<Object>(null),
  final int i => Variable<int>(i),
  final double d => Variable<double>(d),
  final String s => Variable<String>(s),
  final bool b => Variable<bool>(b),
  final Uint8List b => Variable<Uint8List>(b),
  final DateTime d => Variable<DateTime>(d),
  _ => Variable<String>(v.toString()),
};
