import 'package:flutter/material.dart';
import '../design_tokens.dart';
import '../services/profile_store.dart';

/// Persistent banner shown on adult surfaces when a profile save failed,
/// with a manual retry. Clears automatically on the next successful save.
class SaveFailedBanner extends StatelessWidget {
  const SaveFailedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: profileSaveFailed,
      builder: (context, failed, _) {
        if (!failed) return const SizedBox.shrink();
        return Semantics(
          liveRegion: true,
          child: Material(
            color: TyperColors.warningSurface,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.error_outline, color: TyperColors.warningInk),
              title: Text(
                "Changes could not be saved. Your device storage may be full.",
                style: TextStyle(color: TyperColors.warningInk, fontSize: 14),
              ),
              trailing: TextButton(
                onPressed: () => retryProfileSave(),
                child: const Text('Retry'),
              ),
            ),
          ),
        );
      },
    );
  }
}
