/// Non-web stub: the Piper WASM engine only exists in browsers. On native the
/// device TTS is already an offline voice, so these are never used.
bool piperSupported() => false;
String piperState() => 'unsupported';
double piperProgress() => 0;
void piperWarm() {}
void piperSetVoice(String voiceId) {}
Future<String> piperSpeak(String text) => Future.value('');
