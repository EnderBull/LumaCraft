import 'dart:async';
import 'dart:io';

import 'photo_state.dart';

/// Gate in front of every write to the user's local data (layout, settings,
/// presets, photo records, export progress).
///
/// "Clear usage records" deletes those files and then closes the app. Without
/// a gate, a save that was already queued, or the one every window close
/// makes, would simply write the old data back. Once [frozen] is set, every
/// write becomes a no-op; [waitIdle] lets the ones already in flight finish
/// before the files are removed.
class UsageData {
  UsageData._();

  /// True from the moment clearing starts until the app closes.
  static bool frozen = false;

  /// Number of exports currently running. Clearing is refused while > 0,
  /// because an export keeps writing its own progress record.
  static int exportsRunning = 0;

  static int _active = 0;
  static Completer<void>? _idle;

  /// Runs one file write unless the data is being cleared.
  static Future<void> write(Future<void> Function() body) async {
    if (frozen) return;
    _active++;
    try {
      await body();
    } finally {
      _active--;
      if (_active == 0) {
        _idle?.complete();
        _idle = null;
      }
    }
  }

  /// Writes [contents] to a temporary file beside [target] and swaps it in.
  ///
  /// On Windows a back-to-back rename onto an existing file can transiently
  /// fail with access denied when Defender or the search indexer holds the
  /// target for a few milliseconds. Retry briefly, and if rename still fails,
  /// fall back to writing the target directly and cleaning up the temp file.
  static Future<void> writeStringAtomic(
    File target,
    String contents, {
    String suffix = '.pending',
    bool gated = true,
  }) {
    Future<void> op() async {
      await target.parent.create(recursive: true);
      final temp = File('${target.path}$suffix');
      await temp.writeAsString(contents, flush: true);
      await commitTempFile(temp, target, contents);
    }

    return gated ? write(op) : op();
  }

  /// Swaps [temp] onto [target] with Windows retry and direct-write fallback.
  static Future<void> commitTempFile(
    File temp,
    File target,
    String contents,
  ) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await temp.rename(target.path);
        return;
      } catch (_) {
        if (Zone.current == Zone.root) {
          await Future<void>.delayed(const Duration(milliseconds: 15));
        }
      }
    }
    try {
      await temp.rename(target.path);
      return;
    } catch (_) {
      await target.writeAsString(contents, flush: true);
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
    }
  }

  /// Completes when no write is in flight.
  static Future<void> waitIdle() {
    if (_active == 0) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  /// The files "clear usage records" removes, and nothing else. Photos and
  /// the built-in preset library (`builtin-working.json`) are never listed.
  static const files = [
    'editor-presets.json',
    'photo-state.json',
    'workspace.json',
    'export-settings.json',
    'app-settings.json',
    'export-recovery.json',
  ];

  /// Every file name to remove: the files, their temporary leftovers, and the
  /// marker the native window code leaves beside the export record.
  static List<String> targetNames() => [
        for (final name in files)
          for (final suffix in const ['', '.pending', '.writing']) '$name$suffix',
        'export-recovery.dismissed',
      ];

  /// Deletes the files in [dir]. Returns the names that could not be removed,
  /// with the reason, so the caller can show them and offer a retry.
  static Future<({int removed, List<String> failed})> clearFiles(
      Directory dir) async {
    var removed = 0;
    final failed = <String>[];
    for (final name in targetNames()) {
      final file = File('${dir.path}/$name');
      try {
        if (await file.exists()) {
          await file.delete();
          removed++;
        }
      } catch (e) {
        failed.add('$name（$e）');
      }
    }
    // Export batch files carry a changing id, so they are matched by name.
    try {
      await for (final entity in dir.list()) {
        final name = entity.uri.pathSegments.last;
        if (entity is File && name.startsWith('export-batch-')) {
          try {
            await entity.delete();
            removed++;
          } catch (e) {
            failed.add('$name（$e）');
          }
        }
      }
    } catch (e) {
      failed.add('读取数据目录失败（$e）');
    }
    return (removed: removed, failed: failed);
  }

  /// Freezes writes, lets in-flight ones finish, then deletes the files.
  /// Returns what could not be removed; empty means the data is gone. Writes
  /// stay frozen until [unfreeze], so a half-cleared state cannot be refilled
  /// by a late save. Calling it again retries only what is left.
  static Future<({int removed, List<String> failed})> clearAll(
      Directory dir) async {
    frozen = true;
    await waitIdle();
    return clearFiles(dir);
  }

  /// Gives up on clearing (the user cancelled after a failure).
  static void unfreeze() => frozen = false;

  /// Standard data folder.
  static Directory standardDirectory() => PhotoStore.defaultFile().parent;

  /// Test hook: back to the normal state.
  static void reset() {
    frozen = false;
    exportsRunning = 0;
  }
}
