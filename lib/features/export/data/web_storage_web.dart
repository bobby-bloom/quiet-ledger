import 'dart:js_interop';

@JS('navigator.storage')
external _StorageManager? get _storage;

extension type _StorageManager._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> persist();
  external JSPromise<JSBoolean> persisted();
}

/// Asks the browser to keep this site's storage (StorageManager.persist).
/// Null when the browser has no StorageManager.
Future<bool?> requestPersistentStorage() async {
  final s = _storage;
  if (s == null) return null;
  try {
    if ((await s.persisted().toDart).toDart) return true;
    return (await s.persist().toDart).toDart;
  } on Object {
    return null;
  }
}

/// Whether this site's storage is persistent; null when unknown.
Future<bool?> isStoragePersistent() async {
  final s = _storage;
  if (s == null) return null;
  try {
    return (await s.persisted().toDart).toDart;
  } on Object {
    return null;
  }
}
