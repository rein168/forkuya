import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typer/services/profile_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initGlobals();
  });

  group('first launch', () {
    test('creates a default profile with starter phrases, all active', () {
      expect(availableProfileIds, ['default']);
      expect(currentProfile.name, 'Teacher');
      expect(getPhrasebook(), containsAll(['Yes', 'No', 'I want to eat', 'I want to play']));
      for (final phrase in getPhrasebook()) {
        expect(isPhraseActive(phrase), isTrue, reason: '"$phrase" should start active');
      }
    });
  });

  group('phrases', () {
    test('addPhrase normalises to sentence case and activates', () {
      addPhrase('  i want WATER  ');
      expect(getPhrasebook(), contains('I want water'));
      expect(isPhraseActive('I want water'), isTrue);
    });

    test('deactivating one phrase does not affect the others', () {
      togglePhraseActive('Yes', false);
      expect(isPhraseActive('Yes'), isFalse);
      expect(getActivePhrases(), isNot(contains('Yes')));
      expect(isPhraseActive('No'), isTrue);
    });

    test('deactivating the last phrase leaves none active (not all)', () {
      for (final phrase in List<String>.from(getPhrasebook())) {
        togglePhraseActive(phrase, false);
      }
      expect(getActivePhrases(), isEmpty);
      expect(isPhraseActive('Yes'), isFalse);
    });

    test('removePhrase drops it from active phrases too', () {
      removePhrase('Yes');
      expect(getPhrasebook(), isNot(contains('Yes')));
      expect(getActivePhrases(), isNot(contains('Yes')));
    });

    test('editPhrase carries the access count over', () {
      incrementPhraseAccessCount('Yes');
      incrementPhraseAccessCount('Yes');
      editPhrase('Yes', 'Yes please');
      expect(getPhrasebook(), isNot(contains('Yes')));
      expect(getPhrasebook(), contains('Yes please'));
      expect(getPhraseAccessCount('Yes please'), 2);
    });

    test('toggleTopPhrase enforces the limit of 10', () {
      for (var i = 0; i < 10; i++) {
        addPhrase('Phrase number $i');
        expect(toggleTopPhrase('Phrase number $i', true), isTrue);
      }
      addPhrase('One too many');
      expect(toggleTopPhrase('One too many', true), isFalse);
    });
  });

  group('themes and words', () {
    test('createTheme and addWordToTheme round trip', () {
      createTheme('ANIMALS');
      addWordToTheme('ANIMALS', 'CAT');
      addWordToTheme('ANIMALS', 'DOG');
      expect(getAvailableThemes(), contains('ANIMALS'));
      expect(getWordsForTheme('ANIMALS'), containsAll(['CAT', 'DOG']));

      removeWordFromTheme('ANIMALS', 'CAT');
      expect(getWordsForTheme('ANIMALS'), ['DOG']);
    });

    test('scheduled themes drive getWordsForDate', () {
      final date = DateTime(2026, 7, 11);
      createTheme('FOOD');
      addWordToTheme('FOOD', 'RICE');
      addThemeToDate(date, 'FOOD');

      expect(getActiveThemesForDate(date), ['FOOD']);
      expect(getWordsForDate(date), ['RICE']);

      removeThemeFromDate(date, 'FOOD');
      expect(getActiveThemesForDate(date), isEmpty);
      expect(getWordsForDate(date), ['CAT', 'DOG', 'BIRD']); // fallback
    });
  });

  group('typing history', () {
    test('logTypedSentence caps history at 50', () {
      for (var i = 0; i < 60; i++) {
        logTypedSentence('sentence $i');
      }
      expect(getTypingHistory().length, 50);
      expect(getTypingHistory().first, 'sentence 10');
    });

    test('processFreeTypedSentence counts known phrases instead of logging', () {
      processFreeTypedSentence('yes');
      expect(getPhraseAccessCount('Yes'), 1);
      expect(getTypingHistory(), isNot(contains('yes')));

      processFreeTypedSentence('something brand new');
      expect(getTypingHistory(), contains('something brand new'));
    });
  });

  group('profiles', () {
    test('createNewProfile switches to the new profile with defaults', () async {
      await createNewProfile('Ana', 'pig');
      expect(currentProfile.name, 'Ana');
      expect(currentProfile.avatar, 'pig');
      expect(getPhrasebook(), isNotEmpty);
      expect(availableProfileIds.length, 2);
    });

    test('deleteProfile falls back to another profile', () async {
      await createNewProfile('Ana', 'pig');
      final anaId = currentProfileId;
      await deleteProfile(anaId);
      expect(availableProfileIds, isNot(contains(anaId)));
      expect(currentProfileId, isNot(anaId));
    });

    test('export then import-merge combines data from both sides', () async {
      addPhrase('Exported phrase');
      final exported = exportCurrentProfileJSON();

      removePhrase('Exported phrase');
      addPhrase('Newer local phrase');

      // Merging the old export back must keep the newer local removal
      // (LWW) and the newer local phrase.
      final ok = await importAndMergeProfileJSON(exported);
      expect(ok, isTrue);
      expect(getPhrasebook(), contains('Newer local phrase'));
      expect(getPhrasebook(), isNot(contains('Exported phrase')));
    });

    test('import of an unknown profile creates it', () async {
      final exported = exportCurrentProfileJSON()
          .replaceAll('"id":"default"', '"id":"other-device"');
      final ok = await importAndMergeProfileJSON(exported);
      expect(ok, isTrue);
      expect(availableProfileIds, contains('other-device'));
    });

    test('import of garbage fails gracefully', () async {
      expect(await importAndMergeProfileJSON('not json at all'), isFalse);
    });
  });
}
