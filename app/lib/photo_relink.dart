import 'photo_state.dart';

/// A record whose photo is no longer where the record says it is.
///
/// Photos get moved between folders all the time. A record is only ever
/// carried over when the file name AND the capture time both match, so a
/// same-named photo from another shoot is never silently taken over.
class PendingRecord {
  final String oldPath, fileName;
  final String? captureTime;
  final bool edited;
  const PendingRecord(this.oldPath, this.fileName, this.captureTime,
      {required this.edited});
}

String recordFileName(String path) {
  final parts = path.split(RegExp(r'[\\/]'));
  return parts.isEmpty ? path : parts.last;
}

/// Records that still have something to match against in this folder.
///
/// A record only counts when its photo is gone AND the folder holds a photo
/// that could actually be it: same file name, or same capture time, and that
/// photo has no content of its own yet. Otherwise there is nothing the user
/// could do about it, and a permanent "relink" prompt for it would be wrong.
List<PendingRecord> pendingRecords({
  required Map<String, PhotoState> records,
  required Set<String> currentPaths,
  Map<String, String> timesByPath = const {},
}) {
  final present = {
    for (final path in currentPaths) path.toLowerCase()
  };
  final freeNames = <String>{};
  final freeTimes = <String>{};
  for (final path in currentPaths) {
    final record = records[path];
    if (record != null && record.hasContent) continue;
    freeNames.add(recordFileName(path).toLowerCase());
    final time = timesByPath[path]?.trim() ?? '';
    if (time.isNotEmpty) freeTimes.add(time);
  }

  final pending = <PendingRecord>[];
  for (final entry in records.entries) {
    if (present.contains(entry.key.toLowerCase())) continue;
    final fileName = recordFileName(entry.key);
    final time = entry.value.captureTime?.trim() ?? '';
    final related = freeNames.contains(fileName.toLowerCase()) ||
        (time.isNotEmpty && freeTimes.contains(time));
    if (!related) continue;
    pending.add(PendingRecord(entry.key, fileName, time.isEmpty ? null : time,
        edited: entry.value.edited));
  }
  pending.sort((a, b) {
    final byName = a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase());
    return byName != 0 ? byName : a.oldPath.compareTo(b.oldPath);
  });
  return pending;
}

/// Pairs records with files that share exactly the same capture time.
///
/// This only proposes pairs; the user still confirms them. A time that
/// appears on more than one side is ambiguous and is left out, so a batch of
/// photos shot in the same second never gets paired by guesswork.
List<(PendingRecord, String)> suggestPairs({
  required List<PendingRecord> records,
  required Map<String, String> timesByPath,
}) {
  final byTime = <String, List<String>>{};
  for (final entry in timesByPath.entries) {
    final time = entry.value.trim();
    if (time.isEmpty) continue;
    byTime.putIfAbsent(time, () => []).add(entry.key);
  }
  final recordTimes = <String, int>{};
  for (final record in records) {
    final time = record.captureTime?.trim() ?? '';
    if (time.isEmpty) continue;
    recordTimes[time] = (recordTimes[time] ?? 0) + 1;
  }
  final pairs = <(PendingRecord, String)>[];
  final used = <String>{};
  for (final record in records) {
    final time = record.captureTime?.trim() ?? '';
    if (time.isEmpty) continue;
    if ((recordTimes[time] ?? 0) > 1) continue;
    final matches = byTime[time];
    if (matches == null || matches.length != 1) continue;
    final path = matches.single;
    if (!used.add(path)) continue;
    pairs.add((record, path));
  }
  return pairs;
}

/// One record that should move to a different path.
class Move {
  final String from, to;
  const Move(this.from, this.to);
}

/// Moves records to follow their photo's content.
///
/// A record remembers a fingerprint of the pixels it belonged to. When a file
/// at the record's own path no longer matches, but another file in the folder
/// does, the two files were renamed or swapped, and the record belongs with
/// its pixels. Nothing moves when the fingerprint cannot be matched exactly.
///
/// The target must be free: if the file at the target path already has a
/// record of its own with content, the move is skipped rather than merged.
List<Move> followContent({
  required Map<String, PhotoState> records,
  required Map<String, String> fingerprintsByPath,
}) {
  final byFingerprint = <String, String>{};
  for (final entry in fingerprintsByPath.entries) {
    final print = entry.value.trim();
    if (print.isEmpty) continue;
    // Two files with identical content are ambiguous; leave them alone.
    if (byFingerprint.containsKey(print)) {
      byFingerprint[print] = '';
    } else {
      byFingerprint[print] = entry.key;
    }
  }
  final candidates = <Move>[];
  final targets = <String>{};
  for (final entry in records.entries) {
    final print = entry.value.fingerprint?.trim() ?? '';
    if (print.isEmpty) continue;
    final here = fingerprintsByPath[entry.key];
    if (here != null && here == print) continue;
    final target = byFingerprint[print];
    if (target == null || target.isEmpty || target == entry.key) continue;
    if (!targets.add(target)) continue;
    candidates.add(Move(entry.key, target));
  }
  // A swap lands every record on a path that is currently taken — by the
  // record that is about to move away. Only a path whose record stays put is
  // a real conflict.
  final leaving = {
    for (final move in candidates) move.from,
  };
  return candidates.where((move) {
    final existing = records[move.to];
    return existing == null || !existing.hasContent || leaving.contains(move.to);
  }).toList();
}

/// Applies [followContent] moves in two passes, so a swap (A→B and B→A) and
/// longer chains both end up correct instead of overwriting each other.
bool applyMoves(Map<String, PhotoState> records, List<Move> moves) {
  if (moves.isEmpty) return false;
  final detached = <Move, PhotoState>{};
  for (final move in moves) {
    final record = records.remove(move.from);
    if (record != null) detached[move] = record;
  }
  var applied = false;
  for (final move in moves) {
    final record = detached[move];
    if (record == null) continue;
    records[move.to] = record;
    applied = true;
  }
  return applied;
}

/// Best new path for a record, or null when the answer is not certain.
///
/// Without a capture time, or when several files look identical, the record
/// is left for the manual dialog instead of guessing.
String? findRelinkedPath({
  required PendingRecord record,
  required Map<String, String> timesByPath,
}) {
  final time = record.captureTime?.trim() ?? '';
  if (time.isEmpty) return null;
  final wanted = record.fileName.toLowerCase();
  String? only;
  for (final entry in timesByPath.entries) {
    if (recordFileName(entry.key).toLowerCase() != wanted) continue;
    if (entry.value.trim() != time) continue;
    if (only != null) return null;
    only = entry.key;
  }
  return only;
}
