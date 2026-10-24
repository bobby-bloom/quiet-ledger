// Native database file operations that must work without an open database
// (recovery from an unreadable file) or before migrations run. The web
// keeps its database in browser storage and gets the stub.
export 'db_files_stub.dart' if (dart.library.io) 'db_files_io.dart';
