import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// A page route for transitions from a child surface into a teacher/adult
/// surface (Settings, Teacher Setup, Schedule Words). Marks the handover
/// as a *moment* — a soft fade + a briefly-visible "Passing to teacher…"
/// chip — so a child watching the tablet knows their world is being
/// borrowed rather than replaced without warning.
///
/// Use like [MaterialPageRoute]:
///   Navigator.push(context, TeacherRoute(builder: (_) => const SettingsScreen()));
class TeacherRoute<T> extends PageRouteBuilder<T> {
  TeacherRoute({required WidgetBuilder builder, String? label})
      : super(
          transitionDuration: const Duration(milliseconds: 520),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            final rise = Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(fade);
            return FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: rise,
                child: _HandoverChipOverlay(
                  animation: animation,
                  label: label ?? 'Passing to a grown-up…',
                  child: child,
                ),
              ),
            );
          },
        );
}

/// Renders the passing-chip during the first ~800ms of the forward
/// transition, then fades out cleanly so it never blocks the adult UI.
class _HandoverChipOverlay extends StatelessWidget {
  const _HandoverChipOverlay({
    required this.animation,
    required this.label,
    required this.child,
  });

  final Animation<double> animation;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Chip visible during 0.0 → 0.55 of the transition, then fades out.
    final chipOpacity = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 1.0, curve: Curves.easeIn),
    );
    return Stack(
      children: [
        child,
        Positioned(
          top: 24,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: chipOpacity,
              builder: (context, _) {
                // Bell curve: fade in, hold briefly, fade out.
                final t = chipOpacity.value;
                final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0);
                if (opacity == 0) return const SizedBox.shrink();
                return Center(
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: TyperColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: TyperColors.warningBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: TyperColors.warningInk.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_outline, color: TyperColors.warningInk, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: TyperColors.warningInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
