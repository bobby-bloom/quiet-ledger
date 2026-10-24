import 'package:personal_finance/features/import/domain/background/background_sync.dart'
    if (dart.library.io) 'package:personal_finance/features/import/domain/background/background_io.dart'
    as impl;

/// Runs [computation] off the UI thread: in a background isolate on native
/// platforms, directly (after yielding to the event loop) on the web.
/// [computation] must only capture sendable data.
Future<T> runInBackground<T>(T Function() computation) =>
    impl.runInBackground(computation);
