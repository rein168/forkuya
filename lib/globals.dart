/// Facade kept for backwards compatibility: the app's screens import
/// `globals.dart`, which now just re-exports the split-out modules.
/// New code should import the specific model/service it needs.
library;

export 'models/lww_set.dart';
export 'models/user_profile.dart';
export 'services/profile_store.dart';
export 'services/tts_service.dart';
