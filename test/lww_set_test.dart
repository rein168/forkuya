import 'package:flutter_test/flutter_test.dart';
import 'package:typer/models/lww_set.dart';

void main() {
  group('LWWSet', () {
    test('added elements are active', () {
      final set = LWWSet();
      set.add('apple');
      set.add('banana');
      expect(set.activeElements, containsAll(['apple', 'banana']));
    });

    test('removing an element after adding deactivates it', () {
      final set = LWWSet();
      set.add('apple', 100);
      set.remove('apple', 200);
      expect(set.activeElements, isEmpty);
    });

    test('re-adding after removal reactivates', () {
      final set = LWWSet();
      set.add('apple', 100);
      set.remove('apple', 200);
      set.add('apple', 300);
      expect(set.activeElements, ['apple']);
    });

    test('timestamp ties go to the addition', () {
      final set = LWWSet();
      set.add('apple', 100);
      set.remove('apple', 100);
      expect(set.activeElements, ['apple']);
    });

    test('merge keeps the newest timestamp from each side', () {
      final a = LWWSet();
      final b = LWWSet();
      a.add('shared', 100);
      b.add('shared', 50); // older add on b
      b.add('only-b', 100);
      a.remove('gone', 300);
      b.add('gone', 200); // b re-added before a removed it

      a.merge(b);
      expect(a.activeElements, containsAll(['shared', 'only-b']));
      expect(a.activeElements, isNot(contains('gone')));
      expect(a.additions['shared'], 100); // newest add wins
    });

    test('merge is commutative for active membership', () {
      final a = LWWSet();
      final b = LWWSet();
      a.add('x', 100);
      b.remove('x', 200);
      b.add('y', 100);

      final a2 = LWWSet.fromJson(a.toJson());
      final b2 = LWWSet.fromJson(b.toJson());

      a.merge(b);
      b2.merge(a2);
      expect(a.activeElements.toSet(), b2.activeElements.toSet());
    });

    test('survives a JSON round trip', () {
      final set = LWWSet();
      set.add('apple', 100);
      set.remove('banana', 200);
      final restored = LWWSet.fromJson(set.toJson());
      expect(restored.additions, set.additions);
      expect(restored.removals, set.removals);
    });
  });
}
