import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'photo_state.dart';

String directoryName(String path) =>
    path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).last;

/// How often the folder is compared with the list on screen, as a safety net
/// behind the OS change notifications.
///
/// Measured: listening to a folder costs 1.3 ms for 200 photos, 2.6 ms for
/// 2000 and about 17 ms for 10000 (or for 40 sub-folders holding 6000). Run
/// once every few seconds this is well under a tenth of a percent of one
/// core, and it only lists names: a photo is re-read only when the set of
/// files really changed. Kept because notifications can be dropped — a large
/// copy can overflow the system buffer, and network or synchronised folders
/// do not report reliably. It also caught real misses before the current
/// fixes, so it stays as a backstop rather than being removed.
const verifyInterval = Duration(seconds: 5);

List<String> diskRoots() {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    final volumes = Directory('/Volumes');
    return [
      if (home != null && home.isNotEmpty) home,
      if (volumes.existsSync()) volumes.path,
    ];
  }
  if (!Platform.isWindows) return ['/'];
  final drives = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<Uint32 Function(), int Function()>('GetLogicalDrives')();
  return [
    for (var i = 0; i < 26; i++)
      if (drives & (1 << i) != 0) '${String.fromCharCode(65 + i)}:\\'
  ];
}

Future<List<String>> childDirectories(String path) async {
  final children = <String>[];
  await for (final entity in Directory(path).list(followLinks: false)) {
    if (entity is Directory) children.add(entity.path);
  }
  children.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return children;
}

/// Only one native directory enumeration runs at a time. Cancelling invalidates
/// pending callbacks before the operating system has finished cancellation.
class PhotoScanner {
  StreamSubscription<FileSystemEntity>? _listing;
  Timer? _flush;
  int _generation = 0;

  void cancel() {
    _generation++;
    _flush?.cancel();
    _listing?.cancel();
    _listing = null;
  }

  /// Reads the folders once and returns everything found, in path order.
  ///
  /// Used for refreshing the list after the folder changed on disk: the
  /// complete result is needed to notice deletions, which streaming batches
  /// cannot reveal.
  ///
  /// It does not cancel a scan that is already running: several refreshes and
  /// the first scan may overlap without cutting each other short. Only an
  /// explicit [cancel] (the folder changed) or a new [startMany] invalidates it,
  /// and then `cancelled` is true and `files` is incomplete — the caller must
  /// drop it, never read it as "those photos were deleted".
  Future<({List<File> files, int skipped, bool cancelled})> collect(
      Iterable<String> paths,
      {required bool recursive}) async {
    final ticket = _generation;
    final queue = Queue<String>()..addAll(paths);
    final visited = <String>{}, seenFiles = <String>{};
    String key(String p) => Platform.isWindows
        ? File(p).absolute.path.replaceAll('\\', '/').toLowerCase()
        : File(p).absolute.path;
    final found = <File>[];
    var skipped = 0;
    bool valid() => ticket == _generation;
    while (queue.isNotEmpty) {
      if (!valid()) break;
      final directory = queue.removeFirst();
      if (!visited.add(key(directory))) continue;
      try {
        await for (final entity
            in Directory(directory).list(followLinks: false)) {
          if (!valid()) break;
          if (recursive && entity is Directory) queue.add(entity.path);
          if (entity is File && photoFilePattern.hasMatch(entity.path)) {
            if (seenFiles.add(key(entity.path))) found.add(entity);
          }
        }
      } catch (_) {
        skipped++;
      }
    }
    found.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return (files: found, skipped: skipped, cancelled: !valid());
  }

  void start(String path,
      {required bool recursive,
      required void Function(List<File>) onBatch,
      required void Function(int skipped) onDone,
      required void Function(String message) onError}) {
    startMany([path],
        recursive: recursive,
        onBatch: onBatch,
        onDone: onDone,
        onError: onError);
  }

  void startMany(Iterable<String> paths,
      {required bool recursive,
      required void Function(List<File>) onBatch,
      required void Function(int) onDone,
      required void Function(String) onError}) {
    cancel();
    final ticket = _generation;
    final queue = Queue<String>()..addAll(paths);
    final visited = <String>{}, seenFiles = <String>{};
    String key(String p) => Platform.isWindows
        ? File(p).absolute.path.replaceAll('\\', '/').toLowerCase()
        : File(p).absolute.path;
    var batch = <File>[];
    var skipped = 0;
    bool valid() => ticket == _generation;
    void flush() {
      if (!valid() || batch.isEmpty) return;
      final ready = batch;
      batch = [];
      ready
          .sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
      onBatch(ready);
    }

    void next() {
      if (!valid()) return;
      if (queue.isEmpty) {
        _flush?.cancel();
        _listing = null;
        flush();
        onDone(skipped);
        return;
      }
      final directory = queue.removeFirst();
      if (!visited.add(key(directory))) {
        scheduleMicrotask(next);
        return;
      }
      _listing = Directory(directory).list(followLinks: false).listen((entity) {
        if (!valid()) return;
        if (recursive && entity is Directory) queue.add(entity.path);
        if (entity is File &&
            photoFilePattern.hasMatch(entity.path)) {
          if (!seenFiles.add(key(entity.path))) return;
          batch.add(entity);
          if (batch.length >= 128) flush();
        }
      }, onError: (Object error) {
        if (!valid()) return;
        skipped++;
        onError('$directory：$error');
      }, onDone: () {
        if (valid()) scheduleMicrotask(next);
      }, cancelOnError: false);
    }

    _flush = Timer.periodic(const Duration(milliseconds: 90), (_) => flush());
    next();
  }
}

/// Watches the folders on screen and reports when a new photo appears.
///
/// Photos are often copied in while the app is open; without this the user
/// had to switch folders and back to see them. The OS notification is used
/// only as a hint: the caller re-scans, so nothing is missed when an event is
/// coalesced or arrives while the folder is momentarily unreachable.
///
/// Measured on Windows: deleting to the recycle bin, Shift+Delete, renaming
/// and moving a photo out of the folder all raise an event. The periodic
/// check below is therefore a safety net rather than the main path — it
/// covers bursts that overflow the system buffer, network shares and
/// synchronised folders, where events can be dropped.
class PhotoFolderWatch {
  final _watchers = <String, StreamSubscription<FileSystemEvent>>{};
  Timer? _debounce;
  int _generation = 0;

  void stop() {
    _generation++;
    _debounce?.cancel();
    _debounce = null;
    for (final watcher in _watchers.values) {
      watcher.cancel();
    }
    _watchers.clear();
  }

  /// Starts watching each folder; nested folders are included separately
  /// because the platform watcher is not recursive. Every change counts —
  /// added, deleted, renamed — so the list always matches the folder.
  Future<void> start(Iterable<String> directories,
      {required bool recursive,
      required VoidCallback onChanged,
      void Function(Object error)? onError}) async {
    stop();
    final ticket = _generation;
    final roots = directories.toList();
    final targets = <String>{...roots};
    if (recursive) {
      for (final root in roots) {
        try {
          await for (final entity in Directory(root).list(
              recursive: true, followLinks: false)) {
            if (ticket != _generation) return;
            if (entity is Directory) targets.add(entity.path);
          }
        } catch (error) {
          onError?.call(error);
        }
      }
    }
    for (final path in targets) {
      if (ticket != _generation) return;
      try {
        final watcher = Directory(path)
            .watch(events: FileSystemEvent.all, recursive: false)
            .listen((event) {
          if (ticket != _generation) return;
          _scheduleRefresh(ticket, onChanged);
        }, onError: (Object error) {
          onError?.call(error);
        }, cancelOnError: false);
        _watchers[path] = watcher;
      } catch (error) {
        onError?.call(error);
      }
    }
  }

  /// Copying or deleting a batch of photos fires many events; wait for the
  /// burst to end so the folder is re-scanned once instead of dozens of times.
  void _scheduleRefresh(int ticket, VoidCallback onChanged) {
    if (ticket != _generation) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (ticket != _generation) return;
      onChanged();
    });
  }
}

List<File> mergePhotos(List<File> existing, List<File> incoming) {  final merged = <File>[];
  var a = 0, b = 0;
  while (a < existing.length && b < incoming.length) {
    if (existing[a]
            .path
            .toLowerCase()
            .compareTo(incoming[b].path.toLowerCase()) <=
        0) {
      merged.add(existing[a++]);
    } else {
      merged.add(incoming[b++]);
    }
  }
  return merged
    ..addAll(existing.skip(a))
    ..addAll(incoming.skip(b));
}
