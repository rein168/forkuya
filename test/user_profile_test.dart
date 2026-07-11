import 'package:flutter_test/flutter_test.dart';
import 'package:typer/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('JSON round trip preserves data', () {
      final p = UserProfile(id: 'p1', name: 'Sam', avatar: 'octopus');
      p.phrasebook.add('I want juice');
      p.wordsByTheme.add('ANIMALS||CAT');
      p.phraseAccessCount['I want juice'] = 3;
      p.typingHistory = ['hello there'];
      p.voicePreference = 'BOY';
      p.ttsEnabled = true;
      p.autoHideKeyboard = false; // non-default, proves it round trips

      final restored = UserProfile.fromJson(p.toJson());
      expect(restored.id, 'p1');
      expect(restored.name, 'Sam');
      expect(restored.avatar, 'octopus');
      expect(restored.phrasebook.activeElements, ['I want juice']);
      expect(restored.wordsByTheme.activeElements, ['ANIMALS||CAT']);
      expect(restored.phraseAccessCount['I want juice'], 3);
      expect(restored.typingHistory, ['hello there']);
      expect(restored.voicePreference, 'BOY');
      expect(restored.ttsEnabled, true);
      expect(restored.autoHideKeyboard, false);
    });

    test('autoHideKeyboard defaults to true for older profiles without the field', () {
      final restored = UserProfile.fromJson({'id': 'x', 'name': 'Sam'});
      expect(restored.autoHideKeyboard, true);
    });

    test('legacy placeholder names are upgraded to Teacher', () {
      final restored = UserProfile.fromJson({'id': 'x', 'name': 'New Student'});
      expect(restored.name, 'Teacher');
    });

    test('merge combines phrasebooks and takes max access counts', () {
      final local = UserProfile(id: 'p1', name: 'Sam');
      final remote = UserProfile(id: 'p1', name: 'Sam');

      local.phrasebook.add('Local phrase', 100);
      remote.phrasebook.add('Remote phrase', 100);
      local.phraseAccessCount['Yes'] = 2;
      remote.phraseAccessCount['Yes'] = 5;
      local.typingHistory = ['a'];
      remote.typingHistory = ['b'];

      local.merge(remote);
      expect(local.phrasebook.activeElements, containsAll(['Local phrase', 'Remote phrase']));
      expect(local.phraseAccessCount['Yes'], 5);
      expect(local.typingHistory.toSet(), {'a', 'b'});
    });

    test('merge respects remote deletions that are newer', () {
      final local = UserProfile(id: 'p1', name: 'Sam');
      final remote = UserProfile(id: 'p1', name: 'Sam');

      local.phrasebook.add('Old phrase', 100);
      remote.phrasebook.add('Old phrase', 100);
      remote.phrasebook.remove('Old phrase', 200);

      local.merge(remote);
      expect(local.phrasebook.activeElements, isNot(contains('Old phrase')));
    });

    test('merged typing history is capped at 50 entries', () {
      final local = UserProfile(id: 'p1', name: 'Sam');
      final remote = UserProfile(id: 'p1', name: 'Sam');
      local.typingHistory = List.generate(40, (i) => 'local $i');
      remote.typingHistory = List.generate(40, (i) => 'remote $i');

      local.merge(remote);
      expect(local.typingHistory.length, 50);
    });
  });
}
