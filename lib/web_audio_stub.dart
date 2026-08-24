/// Non-web stub: managed audio elements only exist in browsers. On native the
/// TTS service uses http + BytesSource instead, so these are never called.
Future<bool> fetchAndPlayFreeAudio(String url) => Future.value(false);

Future<bool> playManagedUrl(String url) => Future.value(false);

Future<void> stopManagedAudio() async {}
