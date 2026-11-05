import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:io';

String directoryName(String path) =>
    path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).last;

List<String> diskRoots() {
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
            RegExp(r'\.jpe?g$', caseSensitive: false).hasMatch(entity.path)) {
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

List<File> mergePhotos(List<File> existing, List<File> incoming) {
  final merged = <File>[];
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
