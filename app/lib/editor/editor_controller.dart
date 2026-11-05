import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'style_document.dart';

class EditorController extends ChangeNotifier {
  StyleDocument doc;
  final selection = <String>{}, collapsed = <String>{};
  final List<StyleDocument> _undo = [], _redo = [];
  StyleDocument? _gesture;
  String? rangeAnchor;
  bool snap = true;
  EditorController(this.doc);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  List<StyleNode> get selectedNodes =>
      selection.expand(doc.leaves).toSet().map((id) => doc.node(id)!).toList();
  bool isProtected(String id) =>
      doc.locked(id) || doc.leaves(id).any(doc.locked);
  bool get protected => selection.any(isProtected);
  void update() => notifyListeners();
  void edit(VoidCallback action) {
    final before = doc.copy();
    action();
    doc.normalise();
    if (_gesture == null && !styleEquals(before, doc)) {
      _undo.add(before);
      if (_undo.length > 60) _undo.removeAt(0);
      _redo.clear();
    }
    selection
        .removeWhere((id) => doc.node(id) == null && doc.group(id) == null);
    notifyListeners();
  }

  void begin() {
    _gesture ??= doc.copy();
  }

  void end({bool cancel = false}) {
    final before = _gesture;
    _gesture = null;
    if (before == null) return;
    if (cancel) {
      doc = before;
    } else if (_gesture == null && !styleEquals(before, doc)) {
      _undo.add(before);
      _redo.clear();
    }
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(doc.copy());
    doc = _undo.removeLast();
    _clean();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(doc.copy());
    doc = _redo.removeLast();
    _clean();
  }

  void _clean() {
    selection
        .removeWhere((id) => doc.node(id) == null && doc.group(id) == null);
    notifyListeners();
  }

  void select(String? id,
      {bool toggle = false, bool range = false, List<String>? rows}) {
    if (id == null) {
      selection.clear();
      notifyListeners();
      return;
    }
    if (range &&
        rows != null &&
        rangeAnchor != null &&
        rows.contains(rangeAnchor) &&
        rows.contains(id)) {
      final a = rows.indexOf(rangeAnchor!), b = rows.indexOf(id);
      if (!toggle) selection.clear();
      selection.addAll(rows.sublist(a < b ? a : b, (a > b ? a : b) + 1));
    } else {
      if (!toggle) selection.clear();
      if (toggle && selection.contains(id)) {
        selection.remove(id);
      } else {
        selection.add(id);
      }
      rangeAnchor = id;
    }
    // An ancestor and its descendant must never move twice.
    selection.removeWhere((item) {
      var p = doc.parent(item);
      while (p != null) {
        if (selection.contains(p)) return true;
        p = doc.parent(p);
      }
      return false;
    });
    notifyListeners();
  }

  void add(String type, double ratio) {
    edit(() {
      final n = StyleNode(
          type: type,
          name: componentNames[type]!,
          text: type == 'author'
              ? '作者签名'
              : type == 'text'
                  ? '新的文字'
                  : '',
          anchor: doc.borders['bottom'] == 0 ? 'photo' : 'bottom');
      doc.nodes.add(n);
      doc.order.add(n.id);
      selection
        ..clear()
        ..add(n.id);
    });
  }

  void group() {
    if (selection.length < 2 || protected) return;
    edit(() {
      final ids = orderedSelection();
      final first = ids.first;
      final parent = doc.parent(first);
      final list = doc.children(parent);
      final pos = list.indexOf(first);
      for (final id in ids) {
        doc.children(doc.parent(id)).remove(id);
      }
      final g = StyleGroup(name: '组件组 ${doc.groups.length + 1}', children: ids);
      doc.groups.add(g);
      list.insert(pos.clamp(0, list.length), g.id);
      selection
        ..clear()
        ..add(g.id);
    });
  }

  List<String> orderedSelection() {
    final result = <String>[];
    void visit(List<String> ids) {
      for (final id in ids) {
        if (selection.contains(id)) {
          result.add(id);
        } else if (doc.group(id) != null) {
          visit(doc.children(id));
        }
      }
    }

    visit(doc.order);
    return result;
  }

  void ungroup() {
    if (protected) return;
    edit(() {
      final selected = selection.toList();
      selection.clear();
      for (final id in selected) {
        final g = doc.group(id);
        if (g == null) {
          selection.add(id);
          continue;
        }
        final list = doc.children(doc.parent(id)), index = list.indexOf(id);
        list.remove(id);
        list.insertAll(index, g.children);
        selection.addAll(g.children);
        doc.groups.remove(g);
      }
    });
  }

  void remove() {
    if (protected) return;
    edit(() {
      for (final id in selection.toList()) {
        final ids = doc.leaves(id).toSet();
        doc.nodes.removeWhere((n) => ids.contains(n.id));
        void erase(String key) {
          final g = doc.group(key);
          if (g != null) {
            for (final child in g.children.toList()) {
              erase(child);
            }
            doc.groups.remove(g);
          }
        }

        doc.children(doc.parent(id)).remove(id);
        erase(id);
      }
      selection.clear();
    });
  }

  void duplicate() {
    if (protected || selection.isEmpty) return;
    edit(() {
      String clone(String id) {
        final g = doc.group(id);
        if (g != null) {
          final copy = StyleGroup(
              name: g.name + ' 副本',
              children: g.children.map(clone).toList(),
              visible: g.visible,
              locked: g.locked);
          doc.groups.add(copy);
          doc.duplicateLayout(id, copy.id, group: true);
          return copy.id;
        }
        final n = doc.node(id)!.copy()
          ..id = newObjectId()
          ..name = doc.node(id)!.name + ' 副本';
        n.x += 1;
        n.y += 1;
        doc.nodes.add(n);
        doc.duplicateLayout(id, n.id);
        return n.id;
      }

      final next = <String>[];
      for (final id in orderedSelection()) {
        final list = doc.children(doc.parent(id));
        final copy = clone(id);
        list.insert(list.indexOf(id) + 1, copy);
        next.add(copy);
      }
      selection
        ..clear()
        ..addAll(next);
    });
  }

  bool reorder(String id, String? parent, int index) =>
      reorderMany([id], parent, index);
  bool reorderMany(List<String> ids, String? parent, int index) {
    if (ids.isEmpty ||
        ids.any(isProtected) ||
        parent != null && doc.locked(parent)) return false;
    var p = parent;
    while (p != null) {
      if (ids.contains(p)) return false;
      p = doc.parent(p);
    }
    edit(() {
      final target = doc.children(parent);
      for (final id in ids) {
        final old = doc.children(doc.parent(id)),
            at = doc.children(doc.parent(id)).indexOf(id);
        if (identical(old, target) && at < index) index--;
        old.remove(id);
      }
      target.insertAll(index.clamp(0, target.length), ids);
    });
    return true;
  }

  void stepOrder(bool up) {
    if (selection.length != 1 || protected) return;
    final id = selection.first,
        list = doc.children(doc.parent(id)),
        i = list.indexOf(id);
    if (up && i < list.length - 1) {
      reorder(id, doc.parent(id), i + 2);
    } else if (!up && i > 0) {
      reorder(id, doc.parent(id), i - 1);
    }
  }

  void changeAnchor(StyleNode n, String anchor, double ratio) =>
      edit(() => StyleGeometry(doc, ratio).reanchor(n, anchor));
  void border(
      String side, double value, double ratio, Map<String, Rect> bounds) {
    edit(() {
      final old = StyleGeometry(doc, ratio);
      final moving = doc.nodes.where((n) => n.anchor == 'bottom').toList();
      final points = {for (final n in moving) n.id: old.point(n)};
      if (doc.linked) {
        for (final k in doc.borders.keys) {
          doc.borders[k] = value;
        }
      } else {
        doc.borders[side] = value;
      }
      if (old.bottom == 0 || doc.borders['bottom'] != 0 || moving.isEmpty)
        return;
      final g = StyleGeometry(doc, ratio);
      Rect? union;
      for (final n in moving) {
        final r = bounds[n.id] ??
            Rect.fromCenter(
                center: points[n.id]!, width: n.fontSize, height: n.fontSize);
        union = union == null ? r : union.expandToInclude(r);
      }
      final r = union!, inset = g.photo.deflate(12);
      double dx = 0;
      if (r.width <= inset.width) {
        dx = dx.clamp(inset.left - r.left, inset.right - r.right);
      } else {
        dx = inset.center.dx - r.center.dx;
      }
      final dy = inset.bottom - r.bottom;
      for (final n in moving) {
        g.reanchor(n, 'photo', point: points[n.id]! + Offset(dx, dy));
      }
    });
  }

  void moveNodes(Map<String, StyleNode> originals, Offset delta, double ratio) {
    final g = StyleGeometry(doc, ratio);
    for (final old in originals.values) {
      final n = doc.node(old.id)!;
      g.reanchor(n, old.anchor, point: g.point(old) + delta);
    }
    notifyListeners();
  }
}
