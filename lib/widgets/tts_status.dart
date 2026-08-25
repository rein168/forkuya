import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../design_tokens.dart';

/// Small app-bar chip telling adults which voice is active right now.
class VoiceStatusChip extends StatelessWidget {
  const VoiceStatusChip({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TtsVoiceMode>(
      valueListenable: ttsVoiceMode,
      builder: (context, mode, _) {
        final (icon, label, color, message) = switch (mode) {
          TtsVoiceMode.cloud => (
            Icons.graphic_eq,
            'Cloud Voice',
            TyperColors.correctDeep,
            'Speaking with the realistic Google Cloud voice.',
          ),
          TtsVoiceMode.free => (
            Icons.auto_awesome,
            'Natural Voice',
            TyperColors.speakBlue,
            'Speaking with a free natural voice — no API key needed.',
          ),
          TtsVoiceMode.kokoro => (
            Icons.offline_bolt,
            'Offline Voice (Kokoro)',
            TyperColors.speakBlue,
            'Speaking with the Kokoro neural offline voice.',
          ),
          TtsVoiceMode.piper => (
            Icons.offline_bolt,
            'Offline Voice (Natural)',
            TyperColors.speakBlue,
            'Speaking with a free, completely offline natural voice.',
          ),
          TtsVoiceMode.local => (
            Icons.offline_pin_outlined,
            'Offline Voice',
            TyperColors.warningInk,
            "Speaking with the device's built-in voice.",
          ),
        };
        return Tooltip(
          message: message,
          child: Chip(
            avatar: Icon(icon, size: 18, color: color),
            label: Text(label, style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.only(right: 8),
          ),
        );
      },
    );
  }
}

/// Orange banner shown only when a configured Cloud voice unexpectedly
/// fell back to the offline one (bad key, quota, or network).
class TtsDegradedBanner extends StatelessWidget {
  const TtsDegradedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ttsDegraded,
      builder: (context, degraded, _) {
        if (!degraded) return const SizedBox.shrink();
        return Semantics(
          liveRegion: true,
          child: Material(
            color: TyperColors.warningSurface,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.warning_amber_rounded, color: TyperColors.warningInk),
              title: Text(
                'The realistic voice is unavailable right now, so the offline voice is being used. '
                'Check your internet connection or API key.',
                style: TextStyle(color: TyperColors.warningInk, fontSize: 14),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Dismiss',
                onPressed: () => ttsDegraded.value = false,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Wraps a screen body so the degradation banner overlays the top edge
/// instead of inserting into the layout — its appearance never shifts
/// content. One pattern, every surface.
class BannerOverlay extends StatelessWidget {
  final Widget child;

  const BannerOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: TtsDegradedBanner(),
        ),
      ],
    );
  }
}
