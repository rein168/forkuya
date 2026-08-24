import 'package:flutter/material.dart';

import 'design_tokens.dart';

class CustomKeyboard extends StatefulWidget {
  final Function(String) onKeyPressed;

  const CustomKeyboard({super.key, required this.onKeyPressed});

  @override
  State<CustomKeyboard> createState() => _CustomKeyboardState();
}

class _CustomKeyboardState extends State<CustomKeyboard> {
  // Labels announced by screen readers for the non-letter keys.
  static const Map<String, String> _semanticLabels = {
    'DEL': 'Delete letter',
    'SPACE': 'Space',
    'ENTER': 'Enter, speak the sentence',
  };

  bool _symbolsPage = false;

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
              widget.onKeyPressed(letter == 'SPACE' ? ' ' : letter);
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

  Widget _buildPageToggleKey() {
    final label = _symbolsPage ? 'ABC' : '123+';
    return Expanded(
      flex: 20,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Semantics(
          label: _symbolsPage ? 'Switch to letters' : 'Switch to numbers and symbols',
          button: true,
          child: ElevatedButton(
            onPressed: () => setState(() => _symbolsPage = !_symbolsPage),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: Colors.grey.shade300,
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Page two exists so phrases containing digits, apostrophes, and other
    // symbols are never untypeable — an AAC phrase must never dead-end.
    final rows = _symbolsPage
        ? [
          [
            _buildKey('1'), _buildKey('2'), _buildKey('3'), _buildKey('4'), _buildKey('5'),
            _buildKey('6'), _buildKey('7'), _buildKey('8'), _buildKey('9'), _buildKey('0'),
          ],
          [
            const Spacer(flex: 10),
            _buildKey("'"), _buildKey('-'), _buildKey(':'), _buildKey(';'),
            const Spacer(flex: 10),
          ],
        ]
        : [
          [
            _buildKey('Q'), _buildKey('W'), _buildKey('E'), _buildKey('R'), _buildKey('T'),
            _buildKey('Y'), _buildKey('U'), _buildKey('I'), _buildKey('O'), _buildKey('P'),
          ],
          [
            const Spacer(flex: 5), // Half key indent
            _buildKey('A'), _buildKey('S'), _buildKey('D'), _buildKey('F'), _buildKey('G'),
            _buildKey('H'), _buildKey('J'), _buildKey('K'), _buildKey('L'),
            const Spacer(flex: 5),
          ],
          [
            const Spacer(flex: 5),
            _buildKey('Z'), _buildKey('X'), _buildKey('C'), _buildKey('V'),
            _buildKey('B'), _buildKey('N'), _buildKey('M'),
            _buildKey(','), _buildKey('.'), _buildKey('?'), _buildKey('!'),
            const Spacer(flex: 5),
          ],
        ];

    return Container(
      color: TyperColors.surfaceSunken,
      padding: const EdgeInsets.all(4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: row,
              ),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPageToggleKey(),
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
