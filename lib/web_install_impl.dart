import 'dart:js_interop';

/// Bridges Chrome's `beforeinstallprompt` event (captured in index.html)
/// so Settings can offer a one-tap "Install" button.
/// iOS Safari never fires this event — there we show manual instructions.

extension type _BeforeInstallPromptEvent._(JSObject obj) implements JSObject {
  external void prompt();
}

@JS('window.__typerDeferredInstall')
external _BeforeInstallPromptEvent? get _deferredInstall;

bool canShowInstallPrompt() => _deferredInstall != null;

Future<void> showInstallPrompt() async {
  _deferredInstall?.prompt();
}
