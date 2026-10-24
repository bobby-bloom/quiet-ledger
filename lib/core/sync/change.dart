import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:personal_finance/core/db/database.dart';
import 'package:personal_finance/core/sync/hlc.dart';

/// Kind of a [Change].
enum SyncOp {
  insert,
  update,
  delete,

  /// Replaces the complete child set of one parent (PLAN.md §4.3:
  /// "transaction splits are merged as a unit"). [Change.entity] is the
  /// child table (e.g. `transaction_splits`), [Change.entityId] the parent
  /// id and [Change.fields] `{'rows': [<raw child row>, ...]}` including
  /// tombstones. See `SyncEngine.childSetTables`.
  replaceSet;

  static SyncOp fromChangeOp(ChangeOp op) => switch (op) {
    ChangeOp.insert => SyncOp.insert,
    ChangeOp.update => SyncOp.update,
    ChangeOp.delete => SyncOp.delete,
  };

  ChangeOp get changeOp => switch (this) {
    SyncOp.insert => ChangeOp.insert,
    SyncOp.update || SyncOp.replaceSet => ChangeOp.update,
    SyncOp.delete => ChangeOp.delete,
  };
}

/// One replicated change, built from a `change_log` row (PLAN.md §4.3).
///
/// [fields] maps SQL column names to JSON values exactly as `SyncWriter`
/// logs them (bools as bool, DateTime as ISO string, blobs as base64). For
/// inserts the engine adds `created_at` and `origin_device_id`; the latest
/// change of a row in a push also carries `deleted_at`, so that row
/// existence is replicated last-writer-wins like every other field.
@immutable
class Change {
  const Change({
    required this.entity,
    required this.entityId,
    required this.op,
    required this.hlc,
    required this.fields,
    required this.originDeviceId,
    this.received,
  });

  /// Builds a change from a local log entry. [originDeviceId] defaults to
  /// the HLC's node id (the device id in the app).
  factory Change.fromLogEntry(ChangeLogEntry e, {String? originDeviceId}) {
    final hlc = Hlc.parse(e.hlc);
    final decoded = jsonDecode(e.changedFields);
    return Change(
      entity: e.entity,
      entityId: e.entityId,
      op: SyncOp.fromChangeOp(e.op),
      hlc: hlc,
      fields: decoded is Map ? decoded.cast<String, Object?>() : const {},
      originDeviceId: originDeviceId ?? hlc.nodeId,
    );
  }

  factory Change.fromJson(Map<String, Object?> j) => Change(
    entity: j['entity']! as String,
    entityId: j['entityId']! as String,
    op: SyncOp.values.byName(j['op']! as String),
    hlc: Hlc.parse(j['hlc']! as String),
    fields: (j['fields']! as Map).cast<String, Object?>(),
    originDeviceId: j['origin']! as String,
    received: j['received'] == null
        ? null
        : Hlc.parse(j['received']! as String),
  );

  /// SQL table name (one of `syncedTableNames`).
  final String entity;
  final String entityId;
  final SyncOp op;
  final Hlc hlc;
  final Map<String, Object?> fields;
  final String originDeviceId;

  /// Position of this change in the backend's log, set by the backend when
  /// it delivers the change on `pull`. The engine stores the highest one as
  /// `sync_state.last_pulled_hlc` and passes it as `since` next time, so
  /// changes that arrive late at the backend (offline devices with older
  /// HLCs) are not skipped. Null for local changes; backends that do not
  /// set it get the change's [hlc] as cursor.
  final Hlc? received;

  /// Identity used for de-duplication (a change is applied at most once).
  String get key => '$entity|$entityId|$hlc|${op.name}';

  Change withReceived(Hlc position) => Change(
    entity: entity,
    entityId: entityId,
    op: op,
    hlc: hlc,
    fields: fields,
    originDeviceId: originDeviceId,
    received: position,
  );

  Change withFields(Map<String, Object?> f) => Change(
    entity: entity,
    entityId: entityId,
    op: op,
    hlc: hlc,
    fields: f,
    originDeviceId: originDeviceId,
    received: received,
  );

  Map<String, Object?> toJson() => {
    'entity': entity,
    'entityId': entityId,
    'op': op.name,
    'hlc': hlc.toString(),
    'fields': fields,
    'origin': originDeviceId,
    if (received != null) 'received': received.toString(),
  };

  @override
  bool operator ==(Object other) =>
      other is Change &&
      other.key == key &&
      const DeepCollectionEquality().equals(other.fields, fields);

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'Change(${op.name} $entity/$entityId @ $hlc)';
}
