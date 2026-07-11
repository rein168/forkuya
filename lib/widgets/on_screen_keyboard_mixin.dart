import 'package:flutter/material.dart';

import '../services/profile_store.dart';

/// Manages whether the on-screen [CustomKeyboard] is shown on a typing screen.
///
/// The keyboard starts visible. The first time a physical key is used we know
/// a hardware keyboard is present, so — if the teacher has left the auto-hide
/// behavior on — the on-screen keyboard collapses to give the letters more
/// room. A toggle button in the app bar lets anyone bring it back (or hide it
/// manually); once the user makes that choice we stop auto-hiding so we don't
/// fight them.
mixin OnScreenKeyboardMixin<T extends StatefulWidget> on State<T> {
  bool _onScreenKeyboardVisible = true;
  bool _userChoseVisibility = false;

  bool get isOnScreenKeyboardVisible => _onScreenKeyboardVisible;

  /// Call from the hardware key handler. Hides the on-screen keyboard the
  /// first time a physical key is pressed, unless auto-hide is disabled for
  /// this profile or the user has already picked a visibility manually.
  void onPhysicalKeyUsed() {
    if (_userChoseVisibility) return;
    if (!getAutoHideKeyboard()) return;
    if (_onScreenKeyboardVisible) {
      setState(() => _onScreenKeyboardVisible = false);
    }
  }

  void toggleOnScreenKeyboard() {
    setState(() {
      _onScreenKeyboardVisible = !_onScreenKeyboardVisible;
      _userChoseVisibility = true;
    });
  }

  /// An app-bar action that shows or hides the on-screen keyboard.
  Widget buildKeyboardToggleButton() {
    return IconButton(
      icon: Icon(
        _onScreenKeyboardVisible ? Icons.keyboard_hide : Icons.keyboard,
        size: 32,
      ),
      tooltip: _onScreenKeyboardVisible ? 'Hide on-screen keyboard' : 'Show on-screen keyboard',
      onPressed: toggleOnScreenKeyboard,
    );
  }
}
