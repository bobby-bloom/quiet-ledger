// Platform file storage for receipt attachments. Native platforms copy the
// file into `<app support dir>/attachments/` and store its name (relative)
// in `attachments.file_path`; the web keeps the bytes in the database
// (`attachments.data`) and has no file storage. Backups carry the files
// (docs/BACKUP.md).
export 'attachment_files_stub.dart'
    if (dart.library.io) 'attachment_files_io.dart';
