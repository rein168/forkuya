import 'package:flutter_test/flutter_test.dart';
import 'package:typer/updater.dart';

void main() {
  group('isNewerVersion', () {
    test('newer patch/minor/major versions are detected', () {
      expect(isNewerVersion('v1.0.7', 'v1.0.6'), isTrue);
      expect(isNewerVersion('v1.1.0', 'v1.0.9'), isTrue);
      expect(isNewerVersion('v2.0.0', 'v1.9.9'), isTrue);
      expect(isNewerVersion('v1.10.0', 'v1.9.9'), isTrue); // not a string compare
    });

    test('same or older versions are not updates', () {
      expect(isNewerVersion('v1.0.6', 'v1.0.6'), isFalse);
      expect(isNewerVersion('v1.0.5', 'v1.0.6'), isFalse); // rollback is not an update
      expect(isNewerVersion('v0.9.9', 'v1.0.0'), isFalse);
    });

    test('handles tags without the v prefix and short versions', () {
      expect(isNewerVersion('1.0.7', 'v1.0.6'), isTrue);
      expect(isNewerVersion('v1.1', '1.0.6'), isTrue);
    });
  });
}
