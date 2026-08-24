/// Non-web stub: managed audio elements only exist in browsers.
Future<bool> checkManagedUrl(String url) => Future.value(false);

Future<void> playManagedUrl(String url) async {}

Future<void> stopManagedAudio() async {}
