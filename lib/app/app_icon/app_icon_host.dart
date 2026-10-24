// The icon the running app shows outside the launcher: the window icon on
// Linux and Windows, the Dock icon on macOS, the favicon on the web. Other
// platforms get the stub.
export 'app_icon_host_stub.dart'
    if (dart.library.io) 'app_icon_host_io.dart'
    if (dart.library.js_interop) 'app_icon_host_web.dart';
