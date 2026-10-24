// Platform file storage for receipt attachments. Native platforms copy the
// file into `<app support dir>/attachments/`; the web keeps the bytes in the
// database (`attachments.data`) and has no file storage.
export 'attachment_store_stub.dart'
    if (dart.library.io) 'attachment_store_io.dart';
