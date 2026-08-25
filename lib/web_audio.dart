/// Managed web-audio bridge: real implementation in browsers, stub elsewhere.
library;

export 'web_audio_stub.dart' if (dart.library.js_interop) 'web_audio_impl.dart';
