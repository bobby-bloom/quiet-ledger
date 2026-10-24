// Persistent browser storage (docs/BACKUP.md): on the web all data lives in
// browser storage, which the browser may clear under storage pressure
// unless the site's storage is persistent. Native platforms get the stub
// (null = not applicable).
export 'web_storage_stub.dart'
    if (dart.library.js_interop) 'web_storage_web.dart';
