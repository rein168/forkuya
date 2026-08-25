/// A Last-Writer-Wins element set (a simple CRDT).
///
/// Each element carries an add timestamp and a remove timestamp; the element
/// is "active" when its latest add is at least as new as its latest remove.
/// Two copies of a set can be merged from different devices without losing
/// either side's changes, which is what makes Profile Code sharing safe.
class LWWSet {
  Map<String, int> additions = {};
  Map<String, int> removals = {};

  LWWSet();

  List<String> get activeElements {
    return additions.keys.where((element) {
      final addTime = additions[element] ?? 0;
      final remTime = removals[element] ?? 0;
      // Ties go to the addition so that a rapid remove-then-re-add within the
      // same millisecond leaves the element active, matching user intent.
      return addTime >= remTime;
    }).toList();
  }

  // Local operations stamp themselves newer than the opposing entry when the
  // clock hasn't advanced yet (several ops can land in the same millisecond),
  // so a local add/remove always takes effect immediately. Explicit
  // timestamps (used when replaying remote data) are stored as-is.
  void add(String element, [int? timestamp]) {
    if (timestamp != null) {
      additions[element] = timestamp;
      return;
    }
    var ts = DateTime.now().millisecondsSinceEpoch;
    final opposing = removals[element];
    if (opposing != null && ts <= opposing) ts = opposing + 1;
    additions[element] = ts;
  }

  void remove(String element, [int? timestamp]) {
    if (timestamp != null) {
      removals[element] = timestamp;
      return;
    }
    var ts = DateTime.now().millisecondsSinceEpoch;
    final opposing = additions[element];
    if (opposing != null && ts <= opposing) ts = opposing + 1;
    removals[element] = ts;
  }

  /// Tombstones every active element so the set becomes empty. Removals are
  /// recorded rather than deleting history, so merging with an older copy
  /// (e.g. a stale Profile Code or backup) cannot resurrect the elements.
  void removeAll() {
    for (final element in activeElements) {
      remove(element);
    }
  }

  void merge(LWWSet other) {
    other.additions.forEach((element, time) {
      if ((additions[element] ?? 0) < time) additions[element] = time;
    });
    other.removals.forEach((element, time) {
      if ((removals[element] ?? 0) < time) removals[element] = time;
    });
  }

  Map<String, dynamic> toJson() => {
    'additions': additions,
    'removals': removals,
  };

  factory LWWSet.fromJson(Map<String, dynamic> json) {
    var set = LWWSet();
    set.additions = Map<String, int>.from(json['additions'] ?? {});
    set.removals = Map<String, int>.from(json['removals'] ?? {});
    return set;
  }
}
