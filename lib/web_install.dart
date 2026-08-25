/// Install-prompt bridge: real implementation in browsers, stub elsewhere.
library;

export 'web_install_stub.dart'
    if (dart.library.js_interop) 'web_install_impl.dart';
