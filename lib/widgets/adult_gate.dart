import 'dart:math';

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Shows a simple multiplication challenge before allowing entry to
/// grown-up areas (Settings, Word Setup, profile deletion). This is not
/// security — it just keeps students from wandering into teacher tools
/// or deleting a profile by accident.
Future<bool> requireAdultGate(BuildContext context, {String? reason}) async {
  final rng = Random();
  final a = 3 + rng.nextInt(7); // 3..9
  final b = 4 + rng.nextInt(6); // 4..9
  final answer = a * b;
  final controller = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: TyperColors.warningInk),
          SizedBox(width: 8),
          Text('Grown-Ups Only'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reason != null) ...[
            Text(reason, style: const TextStyle(color: TyperColors.inkSecondary)),
            const SizedBox(height: 12),
          ],
          Text('To continue, solve: $a × $b = ?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Answer',
            ),
            onSubmitted: (value) {
              Navigator.pop(context, int.tryParse(value.trim()) == answer);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, int.tryParse(controller.text.trim()) == answer);
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  );

  if (result == false && context.mounted) {
    // A wrong answer was submitted (a cancel pops null, not false).
    if (controller.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That answer was not correct.')),
      );
    }
  }
  return result == true;
}
