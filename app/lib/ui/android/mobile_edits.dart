import '../../editor/editor_controller.dart';
import '../../editor/style_document.dart';

typedef _Edit = ({void Function() undo, void Function() redo});

/// Keeps the batch's reusable style and the current session's photo overrides
/// separate. History entries capture the originating photo and preset.
class MobileEdits {
  EditorController _editor;
  StyleDocument? _preview;
  final _undo = <_Edit>[];
  final _redo = <_Edit>[];
  final _captions = <(String, String, String), String>{};
  final _capture = <(String, String), String>{};

  MobileEdits(StyleDocument style) : _editor = EditorController(style.copy());

  StyleDocument get style => _editor.doc;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  bool cancelPreview() {
    if (_preview == null) return false;
    _preview = null;
    return true;
  }

  void loadStyle(StyleDocument next) {
    _preview = null;
    _editor.dispose();
    _editor = EditorController(next.copy());
    _undo.clear();
    _redo.clear();
  }

  void previewComponent(String id, void Function(StyleNode)? change) {
    _preview = null;
    if (change == null || style.node(id) == null || style.locked(id)) return;
    final next = style.copy();
    _editLayouts(next, () => change(next.node(id)!));
    _preview = next;
  }

  void editComponent(String id, void Function(StyleNode) change) {
    _preview = null;
    if (style.node(id) == null || style.locked(id)) return;
    final next = style.copy();
    _editLayouts(next, () => change(next.node(id)!));
    _commitStyle(next);
  }

  void resetComponentNumber(String id, StyleDocument baseline,
      double Function(StyleNode) read, void Function(StyleNode, double) apply) {
    _preview = null;
    if (style.node(id) == null || style.locked(id)) return;
    final next = style.copy();
    final saved = baseline.copy();
    _editLayouts(next, () {
      saved.switchLayout(next.editingLayout);
      final original = saved.node(id);
      if (original != null) apply(next.node(id)!, read(original));
    });
    _commitStyle(next);
  }

  void _commitStyle(StyleDocument next) {
    if (styleEquals(style, next)) return;
    _editor.edit(() => _editor.doc = next);
    _record((undo: _editor.undo, redo: _editor.redo));
  }

  String? caption(String photo, String preset, String node) =>
      _captions[(photo, preset, node)];

  void editCaption(String photo, String preset, String node, String? value) =>
      _set(_captions, (photo, preset, node), value);

  String? captureValue(String photo, String field) => _capture[(photo, field)];

  void editCapture(String photo, String field, String? value) =>
      _set(_capture, (photo, field), value);

  StyleDocument styleFor(String photo, String preset) {
    final active = _preview ?? style;
    if (!active.nodes.any((node) =>
        node.type == 'text' &&
        _captions.containsKey((photo, preset, node.id)))) {
      return active;
    }
    final result = active.copy();
    _editLayouts(result, () {
      for (final node in result.nodes.where((node) => node.type == 'text')) {
        node.text = caption(photo, preset, node.id) ?? node.text;
      }
    });
    return result;
  }

  void _editLayouts(StyleDocument document, void Function() change) {
    document.switchLayout('general');
    change();
    if (!document.adaptive) return;
    for (final orientation in document.layouts.keys.toList()) {
      document.switchLayout(orientation);
      change();
    }
    document.switchLayout('general');
  }

  Map<String, String> fieldsFor(String photo, Map<String, String> original) => {
        ...original,
        for (final entry in _capture.entries)
          if (entry.key.$1 == photo) entry.key.$2: entry.value,
      };

  void _set<K>(Map<K, String> values, K key, String? value) {
    final before = values[key];
    if (before == value) return;
    void apply(String? text) {
      if (text == null) {
        values.remove(key);
      } else {
        values[key] = text;
      }
    }

    apply(value);
    _record((undo: () => apply(before), redo: () => apply(value)));
  }

  void _record(_Edit edit) {
    _undo.add(edit);
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  void undo() {
    _preview = null;
    if (_undo.isEmpty) return;
    final edit = _undo.removeLast();
    edit.undo();
    _redo.add(edit);
  }

  void redo() {
    _preview = null;
    if (_redo.isEmpty) return;
    final edit = _redo.removeLast();
    edit.redo();
    _undo.add(edit);
  }

  Map<String, Object> snapshot(Set<String> paths) => {
        'captions': [
          for (final e in _captions.entries)
            if (paths.contains(e.key.$1))
              [e.key.$1, e.key.$2, e.key.$3, e.value]
        ],
        'capture': [
          for (final e in _capture.entries)
            if (paths.contains(e.key.$1)) [e.key.$1, e.key.$2, e.value]
        ],
      };

  void restore(Map<String, dynamic> data) {
    _captions.clear();
    _capture.clear();
    for (final row in data['captions'] as List) {
      if (row
          case [
            final String path,
            final String preset,
            final String id,
            final String text
          ]) {
        _captions[(path, preset, id)] = text;
      }
    }
    for (final row in data['capture'] as List) {
      if (row case [final String path, final String field, final String text]) {
        _capture[(path, field)] = text;
      }
    }
  }

  void dispose() => _editor.dispose();
}
