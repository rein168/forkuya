import 'dart:async';

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Fades teacher-facing app-bar chrome (theme dropdown, keyboard toggle,
/// voice chip, panel toggles) out of the child's peripheral vision after
/// a period of inactivity, and provides a peek button that pulls the
/// chrome back down. Shared by Module 1 and Module 2 so the sibling
/// activities behave identically.
///
/// Usage:
/// 1. Add [AutoHidingChromeMixin] to a `State<...>` with
///    [SingleTickerProviderStateMixin] (or [TickerProviderStateMixin]).
/// 2. Call [scheduleChromeIdle] once in `initState()`.
/// 3. Call [chromeIdleTimerCancel] in `dispose()`.
/// 4. On any real typing interaction call [noteChildActivity] so the
///    chrome stays out of the way.
/// 5. In `AppBar.actions`, use [buildChromeActions] to wrap the teacher
///    controls and get the peek button for free.
mixin AutoHidingChromeMixin<T extends StatefulWidget> on State<T> {
  bool _chromeExpanded = true;
  Timer? _chromeIdleTimer;

  /// How long the chrome stays visible after the last teacher-touched
  /// interaction. Tuned for a mixed-mode lesson: long enough to reach the
  /// dropdown, short enough to get out of the way for the child.
  Duration get chromeIdleDuration => const Duration(seconds: 5);

  bool get chromeExpanded => _chromeExpanded;

  /// Starts / restarts the idle countdown. Called on entry and after any
  /// interaction that keeps the chrome expanded.
  void scheduleChromeIdle() {
    _chromeIdleTimer?.cancel();
    _chromeIdleTimer = Timer(chromeIdleDuration, () {
      if (!mounted) return;
      if (_chromeExpanded) setState(() => _chromeExpanded = false);
    });
  }

  /// The child pressed a real letter — the chrome should stay collapsed
  /// but reset its countdown if it happens to be up.
  void noteChildActivity() {
    if (_chromeExpanded) scheduleChromeIdle();
  }

  /// Reveals chrome (used after the teacher taps a teacher control) and
  /// restarts the idle countdown.
  void revealChrome() {
    if (!_chromeExpanded) setState(() => _chromeExpanded = true);
    scheduleChromeIdle();
  }

  /// Toggle called by the peek button. Collapses immediately if open,
  /// reveals if collapsed.
  void toggleChrome() {
    if (_chromeExpanded) {
      setState(() => _chromeExpanded = false);
      _chromeIdleTimer?.cancel();
    } else {
      revealChrome();
    }
  }

  /// Cancels the idle timer. Call from `dispose()`.
  void chromeIdleTimerCancel() {
    _chromeIdleTimer?.cancel();
    _chromeIdleTimer = null;
  }

  /// Builds the AppBar.actions list: teacher controls collapse behind a
  /// FadeTransition + horizontal SizeTransition, and a persistent peek
  /// button pulls them back. Feed [teacherActions] the same widgets you
  /// used to hand `AppBar.actions` before adopting this mixin — they'll
  /// be wrapped for you.
  List<Widget> buildChromeActions(List<Widget> teacherActions) {
    return <Widget>[
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SizeTransition(
            sizeFactor: anim,
            axis: Axis.horizontal,
            child: child,
          ),
        ),
        child: _chromeExpanded
            ? Row(
                key: const ValueKey('chrome-expanded'),
                mainAxisSize: MainAxisSize.min,
                children: teacherActions,
              )
            : const SizedBox.shrink(key: ValueKey('chrome-collapsed')),
      ),
      IconButton(
        icon: Icon(
          _chromeExpanded ? Icons.expand_less : Icons.tune,
          size: 26,
          color: TyperColors.inkSecondary,
        ),
        tooltip: _chromeExpanded ? 'Hide teacher controls' : 'Show teacher controls',
        onPressed: toggleChrome,
      ),
      const SizedBox(width: 16),
    ];
  }
}
