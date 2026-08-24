/// Offline Piper TTS bridge: real implementation in browsers, stub elsewhere.
library;

export 'piper_stub.dart' if (dart.library.js_interop) 'piper_impl.dart';
