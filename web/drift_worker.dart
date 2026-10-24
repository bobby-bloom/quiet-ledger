// Drift web worker with SQLite3 Multiple Ciphers encryption.
//
// Build: tool/build_web_worker.sh (dart compile js -O4 -o web/drift_worker.js
// web/drift_worker.dart). Must be used with web/sqlite3mc.wasm.
//
// How the key gets here: the stock `WasmDatabase.workerMainForOpen` only
// takes a synchronous setup callback that does not know which database it
// opens, and drift's protocol has no field for custom data. The app passes
// the key (64 hex chars) in the *fragment* of the sqlite3 WASM URI
// (`sqlite3mc.wasm#k=<hex>`), which drift forwards verbatim in its
// `ServeDriftDatabase` message. A message listener registered before
// drift's own reads the key, removes the fragment from the message (so it is
// never fetched, logged or forwarded further), and the setup callback runs
// `PRAGMA key` when the database is opened. The key never touches storage.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:drift/wasm.dart';
import 'package:sqlite3/common.dart';

/// Key for the database served next; null = unencrypted.
String? _key;
final _hexKey = RegExp(r'^[0-9a-fA-F]{64}$');

void main() {
  final self = globalContext;
  if (self.instanceOfString('DedicatedWorkerGlobalScope')) {
    _interceptServeRequests(self, stripAlways: true);
  } else if (self.instanceOfString('SharedWorkerGlobalScope')) {
    self.callMethod<JSAny?>(
      'addEventListener'.toJS,
      'connect'.toJS,
      ((JSObject event) {
        final ports = (event['ports']! as JSArray<JSObject>).toDart;
        if (ports.isNotEmpty) {
          // The shared worker hosts only `sharedIndexedDb` databases itself
          // and forwards other requests (with the fragment) to a dedicated
          // worker running this same script.
          _interceptServeRequests(ports.first, stripAlways: false);
        }
      }).toJS,
    );
  }
  WasmDatabase.workerMainForOpen(setupAllDatabases: applyCipher);
}

void _interceptServeRequests(JSObject target, {required bool stripAlways}) {
  target.callMethod<JSAny?>(
    'addEventListener'.toJS,
    'message'.toJS,
    ((JSObject event) {
      final data = event['data'];
      if (data == null || !data.isA<JSObject>()) return;
      final msg = data as JSObject;
      final type = msg['type'];
      if (type == null ||
          !type.isA<JSString>() ||
          (type as JSString).toDart != 'ServeDriftDatabase') {
        return;
      }
      final payload = msg['payload'];
      if (payload == null || !payload.isA<JSObject>()) return;
      final p = payload as JSObject;
      final sqlite = p['sqlite'];
      if (sqlite == null || !sqlite.isA<JSString>()) return;
      final uri = Uri.parse((sqlite as JSString).toDart);
      final storage = p['storage'];
      final storageName = storage != null && storage.isA<JSString>()
          ? (storage as JSString).toDart
          : '';
      final servedHere = stripAlways || storageName == 'sharedIndexedDb';
      if (!servedHere) return;
      final k = uri.hasFragment
          ? Uri.splitQueryString(uri.fragment)['k']
          : null;
      _key = k != null && _hexKey.hasMatch(k) ? k : null;
      p['sqlite'] = uri.removeFragment().toString().toJS;
    }).toJS,
  );
}

/// Applies the key to a freshly opened database:
/// * new (empty) file → `PRAGMA key` (created encrypted)
/// * encrypted file → `PRAGMA key`, verified by a read (wrong key throws)
/// * existing plaintext file (created before web encryption) →
///   `PRAGMA rekey` encrypts it in place
///
/// Keep in sync with `_applyCipher` in
/// lib/core/db/connection/connection_web.dart (main-thread fallback).
void applyCipher(CommonDatabase db) {
  final key = _key;
  if (key == null) return;
  if (db.select('PRAGMA cipher').isEmpty) {
    throw StateError('sqlite3mc.wasm is required for an encrypted database');
  }
  final literal = "\"x'$key'\"";
  var readableWithoutKey = true;
  try {
    db.select('SELECT count(*) FROM sqlite_master');
  } on SqliteException {
    readableWithoutKey = false;
  }
  if (!readableWithoutKey) {
    db.execute('PRAGMA key = $literal');
  } else {
    final pages = db.select('PRAGMA page_count').first.values.first;
    db.execute(
      pages == 0 ? 'PRAGMA key = $literal' : 'PRAGMA rekey = $literal',
    );
  }
  // Fails fast with "file is not a database" if the key is wrong.
  db.select('SELECT count(*) FROM sqlite_master');
}
