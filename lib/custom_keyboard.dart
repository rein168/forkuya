import 'package:flutter/material.dart';

class CustomKeyboard extends StatelessWidget {
  final Function(String) onKeyPressed;

  const CustomKeyboard({super.key, required this.onKeyPressed});

  // Labels announced by screen readers for the non-letter keys.
  static const Map<String, String> _semanticLabels = {
    'DEL': 'Delete letter',
    'SPACE': 'Space',
    'ENTER': 'Enter, speak the sentence',
  };

  Widget _buildKey(String letter, {double flex = 1}) {
    return Expanded(
      flex: (flex * 10).toInt(),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Semantics(
          label: _semanticLabels[letter],
          button: true,
          child: ElevatedButton(
            onPressed: () {
              onKeyPressed(letter == 'SPACE' ? ' ' : letter);
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: Colors.white,
            ),
            child: Text(
              letter == 'SPACE' ? 'SPACE' : letter,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildKey('Q'), _buildKey('W'), _buildKey('E'), _buildKey('R'), _buildKey('T'),
                _buildKey('Y'), _buildKey('U'), _buildKey('I'), _buildKey('O'), _buildKey('P'),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 5), // Half key indent
                _buildKey('A'), _buildKey('S'), _buildKey('D'), _buildKey('F'), _buildKey('G'),
                _buildKey('H'), _buildKey('J'), _buildKey('K'), _buildKey('L'),
                const Spacer(flex: 5),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 5),
                _buildKey('Z'), _buildKey('X'), _buildKey('C'), _buildKey('V'),
                _buildKey('B'), _buildKey('N'), _buildKey('M'), 
                _buildKey(','), _buildKey('.'), _buildKey('?'), _buildKey('!'),
                const Spacer(flex: 5),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildKey('DEL', flex: 2),
                _buildKey('SPACE', flex: 6),
                _buildKey('ENTER', flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
