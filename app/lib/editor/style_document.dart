import 'dart:ui';
import 'palette_style.dart';
import 'background_style.dart';
import 'image_mark.dart';

String newObjectId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    (_serial++).toRadixString(36);
int _serial = 0;
const componentNames = {
  'text': '自由文字',
  'author': '作者签名',
  'params': '拍摄参数',
  'camera': '相机型号',
  'lens': '镜头型号',
  'time': '拍摄时间',
  'place': '拍摄地点',
  'palette': '照片色卡',
  'image': '图片标识'
};

class StyleNode {
  String id, type, name, text, anchor, font, align;
  double x, y, fontSize, spacing, opacity;
  int color;
  bool visible, locked;
  PaletteStyle palette;
  ImageMark image;
  StyleNode(
      {String? id,
      this.type = 'text',
      this.name = '自由文字',
      this.text = '新的文字',
      this.anchor = 'bottom',
      this.x = 50,
      this.y = 50,
      this.fontSize = 24,
      this.spacing = 0,
      this.opacity = 100,
      this.color = 0xff544c41,
      this.font = 'sans',
      this.align = 'center',
      this.visible = true,
      this.locked = false,
      PaletteStyle? palette,
      ImageMark? image})
      : palette = palette ?? PaletteStyle(),
        image = image ?? ImageMark(),
        id = id ?? newObjectId();
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        'text': text,
        'anchor': anchor,
        'x': x,
        'y': y,
        'fontSize': fontSize,
        'spacing': spacing,
        'opacity': opacity,
        'color': color,
        'font': font,
        'align': align,
        'visible': visible,
        'locked': locked,
        if (type == 'image') 'image': image.toJson(),
        if (type == 'palette') 'palette': palette.toJson()
      };
  factory StyleNode.fromJson(Map<String, dynamic> j) => StyleNode(
      id: j['id'],
      type: j['type'] ?? 'text',
      name: j['name'] ?? '组件',
      text: j['text'] ?? '',
      anchor: j['anchor'] ?? 'bottom',
      x: (j['x'] as num? ?? 50).toDouble(),
      y: (j['y'] as num? ?? 50).toDouble(),
      fontSize: (j['fontSize'] as num? ?? 24).toDouble(),
      spacing: (j['spacing'] as num? ?? 0).toDouble(),
      opacity: (j['opacity'] as num? ?? 100).toDouble(),
      color: j['color'] is String
          ? int.parse('ff' + (j['color'] as String).replaceFirst('#', ''),
              radix: 16)
          : j['color'] ?? 0xff544c41,
      font: j['font'] ?? 'sans',
      align: j['align'] ?? 'center',
      visible: j['visible'] != false,
      locked: j['locked'] == true,
      image: ImageMark.fromJson(Map<String, dynamic>.from(j['image'] ?? {})),
      palette:
          PaletteStyle.fromJson(Map<String, dynamic>.from(j['palette'] ?? {})));
  StyleNode copy() => StyleNode.fromJson(toJson());
  String content(Map<String, String> fields) {
    if (type == 'text' || type == 'author') return text;
    if (type == 'params')
      return [
        if ((fields['focal'] ?? '').isNotEmpty) '${fields['focal']} mm',
        if ((fields['aperture'] ?? '').isNotEmpty) 'f/${fields['aperture']}',
        if ((fields['shutter'] ?? '').isNotEmpty) '${fields['shutter']} s',
        if ((fields['iso'] ?? '').isNotEmpty) 'ISO ${fields['iso']}'
      ].join('  /  ');
    return fields[type] ?? '';
  }
}

class StyleGroup {
  String id, name;
  List<String> children;
  bool visible, locked;
  StyleGroup(
      {String? id,
      this.name = '组件组',
      List<String>? children,
      this.visible = true,
      this.locked = false})
      : id = id ?? newObjectId(),
        children = children ?? [];
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'children': children,
        'visible': visible,
        'locked': locked
      };
  factory StyleGroup.fromJson(Map<String, dynamic> j) => StyleGroup(
      id: j['id'],
      name: j['name'] ?? '组件组',
      children: List<String>.from(j['children'] ?? []),
      visible: j['visible'] != false,
      locked: j['locked'] == true);
}

class StyleDocument {
  bool adaptive = false;
  String suitability = 'universal';
  String editingLayout = 'general';
  Map<String, dynamic>? _generalLayout;
  final layouts = <String, Map<String, dynamic>>{};
  static const layoutNames = {
    'general': '通用布局',
    'landscape': '横图布局',
    'portrait': '竖图布局'
  };
  static const suitabilityNames = {
    'universal': '横竖通用',
    'landscape': '横图优先',
    'portrait': '竖图优先'
  };
  static String orientation(double ratio) => (ratio - 1).abs() < .000000001
      ? 'general'
      : ratio > 1
          ? 'landscape'
          : 'portrait';
  static dynamic _cloneLayout(dynamic value) => value is Map
      ? <String, dynamic>{
          for (final e in value.entries) e.key as String: _cloneLayout(e.value)
        }
      : value;
  void duplicateLayout(String source, String target, {bool group = false}) {
    final key = group ? 'groups' : 'nodes';
    for (final layout in [
      if (_generalLayout != null) _generalLayout!,
      ...layouts.values
    ]) {
      final entries = layout[key] as Map?;
      if (entries == null || !entries.containsKey(source)) continue;
      final value = _cloneLayout(entries[source]);
      if (!group) {
        for (final axis in ['x', 'y']) {
          if (value[axis] is num) value[axis] = value[axis] + 1;
        }
      }
      entries[target] = value;
    }
  }

  static Map<String, dynamic> nodeLayout(StyleNode n) => {
        'anchor': n.anchor,
        'x': n.x,
        'y': n.y,
        'fontSize': n.fontSize,
        'spacing': n.spacing,
        'align': n.align,
        'visible': n.visible,
        if (n.type == 'image') 'image': {'width': n.image.width},
        if (n.type == 'palette')
          'palette': {
            for (final k in ['size', 'height', 'gap', 'radius', 'scale'])
              k: n.palette.toJson()[k]
          }
      };
  Map<String, dynamic> _captureLayout() => {
        'borders': Map.of(borders),
        'linked': linked,
        'nodes': {for (final n in nodes) n.id: nodeLayout(n)},
        'groups': {for (final g in groups) g.id: g.visible}
      };
  static Map<String, dynamic> _difference(Map current, Map base) {
    final result = <String, dynamic>{};
    for (final e in current.entries) {
      if (e.value is Map && base[e.key] is Map) {
        final nested = _difference(e.value, base[e.key]);
        if (nested.isNotEmpty) result[e.key as String] = nested;
      } else if (e.value != base[e.key]) {
        result[e.key as String] = e.value;
      }
    }
    return result;
  }

  Map<String, dynamic> _currentOverride() =>
      layouts[editingLayout]?['_copied'] == true
          ? {..._captureLayout(), '_copied': true}
          : _difference(_captureLayout(), _generalLayout ?? {});
  Map<String, dynamic> _cleanLayout(Map<String, dynamic> value) => {
        ...value,
        if (value['nodes'] is Map)
          'nodes': {
            for (final n in nodes)
              if ((value['nodes'] as Map).containsKey(n.id))
                n.id: value['nodes'][n.id]
          },
        if (value['groups'] is Map)
          'groups': {
            for (final g in groups)
              if ((value['groups'] as Map).containsKey(g.id))
                g.id: value['groups'][g.id]
          }
      };
  static Map<String, dynamic> _mergeNode(
      Map<String, dynamic> node, dynamic patch) {
    final result = Map<String, dynamic>.from(node);
    if (patch is! Map) return result;
    for (final e in patch.entries) {
      result[e.key as String] = e.value is Map
          ? {
              ...Map<String, dynamic>.from(result[e.key] ?? {}),
              ...Map<String, dynamic>.from(e.value)
            }
          : e.value;
    }
    return result;
  }

  void _applyLayout(Map<String, dynamic> layout) {
    if (layout['borders'] is Map) {
      borders = {
        ...borders,
        ...Map<String, double>.from((layout['borders'] as Map)
            .map((k, v) => MapEntry(k, (v as num).toDouble())))
      };
    }
    linked = layout['linked'] as bool? ?? linked;
    final values = layout['nodes'] as Map? ?? {};
    for (var i = 0; i < nodes.length; i++) {
      nodes[i] = StyleNode.fromJson(
          _mergeNode(nodes[i].toJson(), values[nodes[i].id]));
    }
    final groupValues = layout['groups'] as Map? ?? {};
    for (final g in groups) {
      if (groupValues[g.id] is bool) g.visible = groupValues[g.id];
    }
  }

  void switchLayout(String target) {
    if (!layoutNames.containsKey(target)) return;
    if (!adaptive) target = 'general';
    if (target == editingLayout) return;
    if (editingLayout == 'general') {
      _generalLayout = _captureLayout();
    } else {
      layouts[editingLayout] = _currentOverride();
    }
    if (_generalLayout != null) _applyLayout(_generalLayout!);
    if (target != 'general' && layouts[target] != null)
      _applyLayout(layouts[target]!);
    editingLayout = target;
  }

  void setAdaptive(bool value) {
    if (!value) switchLayout('general');
    adaptive = value;
  }

  void resetLayout() {
    if (editingLayout == 'general') return;
    layouts.remove(editingLayout);
    if (_generalLayout != null) _applyLayout(_generalLayout!);
  }

  void copyGeneralLayout() {
    resetLayout();
    if (editingLayout != 'general') {
      layouts[editingLayout] = {..._captureLayout(), '_copied': true};
    }
  }

  bool get hasLayoutChanges =>
      editingLayout != 'general' && _currentOverride().isNotEmpty;

  StyleDocument forRatio(double ratio) {
    final result = copy();
    result.switchLayout(adaptive ? orientation(ratio) : 'general');
    return result;
  }

  String name;
  int background;
  BackgroundStyle fill;
  FilmStyle film;
  PhotoShadowStyle shadow;
  bool linked;
  Map<String, double> borders;
  List<StyleNode> nodes;
  List<StyleGroup> groups;
  List<String> order;
  StyleDocument(
      {this.name = '我的样式',
      this.background = 0xfff3f0e8,
      this.linked = false,
      BackgroundStyle? fill,
      FilmStyle? film,
      PhotoShadowStyle? shadow,
      Map<String, double>? borders,
      List<StyleNode>? nodes,
      List<StyleGroup>? groups,
      List<String>? order})
      : fill = fill ?? BackgroundStyle(),
        film = film ?? FilmStyle(),
        shadow = shadow ?? PhotoShadowStyle(),
        borders = borders ?? {'top': 3, 'right': 3, 'bottom': 16, 'left': 3},
        nodes = nodes ?? [],
        groups = groups ?? [],
        order = order ?? [];
  factory StyleDocument.template([bool film = false]) {
    final d = StyleDocument(
        name: film ? '胶片档案' : '画廊签名',
        background: film ? 0xff121212 : 0xfff3f0e8);
    d.nodes = [
      StyleNode(
          name: '题签',
          text: 'Gallery Collection',
          font: 'serif',
          fontSize: 32,
          spacing: 3,
          y: 32),
      StyleNode(
          type: 'params',
          name: '拍摄参数',
          text: '',
          fontSize: 14,
          x: 39,
          y: 76,
          color: 0xff77736b),
      StyleNode(
          type: 'author',
          name: '作者签名',
          text: '作者签名',
          font: 'signature',
          fontSize: 26,
          x: 78,
          y: 76)
    ];
    if (film) {
      d.borders = {'top': 3, 'right': 2, 'bottom': 13, 'left': 2};
      for (final n in d.nodes) {
        n.color = 0xffc4a56c;
      }
      d.nodes.first.text = 'FILM ARCHIVE';
    }
    d.order = d.nodes.map((n) => n.id).toList();
    return d;
  }
  Map<String, dynamic> toJson() => {
        'version': 1,
        'adaptive': adaptive,
        'suitability': suitability,
        'layouts': {
          for (final e in layouts.entries) e.key: _cleanLayout(e.value),
          if (editingLayout != 'general')
            editingLayout: _cleanLayout(_currentOverride())
        },
        'name': name,
        'background': background,
        'fill': fill.toJson(),
        'film': film.toJson(),
        'shadow': shadow.toJson(),
        'linked': editingLayout == 'general'
            ? linked
            : _generalLayout?['linked'] ?? linked,
        'borders': editingLayout == 'general'
            ? borders
            : _generalLayout?['borders'] ?? borders,
        'nodes': nodes
            .map((n) => editingLayout == 'general'
                ? n.toJson()
                : _mergeNode(
                    n.toJson(), (_generalLayout?['nodes'] as Map?)?[n.id]))
            .toList(),
        'groups': groups
            .map((g) => {
                  ...g.toJson(),
                  if (editingLayout != 'general' &&
                      (_generalLayout?['groups'] as Map?)?.containsKey(g.id) ==
                          true)
                    'visible': (_generalLayout!['groups'] as Map)[g.id]
                })
            .toList(),
        'order': order
      };
  factory StyleDocument.fromJson(Map<String, dynamic> j) {
    final d = StyleDocument(
        name: j['name'] ?? '我的样式',
        background: j['background'] ?? 0xfff3f0e8,
        linked: j['linked'] == true,
        fill: BackgroundStyle.fromJson(
            Map<String, dynamic>.from(j['fill'] ?? {})),
        film: FilmStyle.fromJson(Map<String, dynamic>.from(j['film'] ?? {})),
        shadow: PhotoShadowStyle.fromJson(
            Map<String, dynamic>.from(j['shadow'] ?? {})),
        borders: (j['borders'] as Map).map((k, v) =>
            MapEntry(k.toString(), (v as num).toDouble().clamp(0, 40))),
        nodes: (j['nodes'] as List)
            .map((n) => StyleNode.fromJson(Map<String, dynamic>.from(n)))
            .toList(),
        groups: (j['groups'] as List? ?? [])
            .map((g) => StyleGroup.fromJson(Map<String, dynamic>.from(g)))
            .toList(),
        order: List<String>.from(j['order'] ?? []));
    d.adaptive = j['adaptive'] == true;
    d.suitability = suitabilityNames.containsKey(j['suitability'])
        ? j['suitability']
        : 'universal';
    for (final key in ['landscape', 'portrait']) {
      if ((j['layouts'] as Map?)?[key] is Map) {
        d.layouts[key] =
            Map<String, dynamic>.from(_cloneLayout(j['layouts'][key]));
      }
    }
    d.normalise();
    return d;
  }
  StyleDocument copy() =>
      StyleDocument.fromJson(toJson())..switchLayout(editingLayout);
  StyleNode? node(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  StyleGroup? group(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  List<String> children(String? id) => id == null ? order : group(id)!.children;
  String? parent(String id) {
    for (final g in groups) {
      if (g.children.contains(id)) return g.id;
    }
    return null;
  }

  List<String> leaves(String id) {
    final g = group(id);
    return g == null
        ? [if (node(id) != null) id]
        : g.children.expand(leaves).toList();
  }

  String root(String id) {
    var p = parent(id);
    while (p != null) {
      id = p;
      p = parent(id);
    }
    return id;
  }

  bool visible(String id) =>
      (node(id)?.visible ?? group(id)?.visible ?? false) &&
      (parent(id) == null || visible(parent(id)!));
  bool locked(String id) =>
      (node(id)?.locked ?? group(id)?.locked ?? false) ||
      (parent(id) != null && locked(parent(id)!));
  List<StyleNode> get painted =>
      order.expand(leaves).map((id) => node(id)!).toList();
  void normalise() {
    final seen = <String>{};
    void walk(List<String> ids, Set<String> path) {
      ids.removeWhere((id) =>
          (node(id) == null && group(id) == null) ||
          seen.contains(id) ||
          path.contains(id));
      for (final id in ids.toList()) {
        if (!seen.add(id)) {
          ids.remove(id);
          continue;
        }
        final g = group(id);
        if (g != null) walk(g.children, {...path, id});
      }
    }

    walk(order, {});
    for (final n in nodes) {
      if (!seen.contains(n.id)) {
        order.add(n.id);
        seen.add(n.id);
      }
    }
  }
}

class StyleGeometry {
  final double photoWidth, photoHeight, top, left, right, bottom;
  StyleGeometry(StyleDocument d, double ratio)
      : photoWidth = ratio >= 1 ? 1000 * ratio : 1000,
        photoHeight = ratio >= 1 ? 1000 : 1000 / ratio,
        top = d.borders['top']! * 10,
        left = d.borders['left']! * 10,
        right = d.borders['right']! * 10,
        bottom = d.borders['bottom']! * 10;
  Size get size => Size(photoWidth + left + right, photoHeight + top + bottom);
  Rect get photo => Rect.fromLTWH(left, top, photoWidth, photoHeight);
  Rect area(String anchor) => anchor == 'photo'
      ? photo
      : anchor == 'bottom'
          ? (bottom > 0
              ? Rect.fromLTWH(0, top + photoHeight, size.width, bottom)
              : photo)
          : Offset.zero & size;
  Offset point(StyleNode n) {
    final r = area(n.anchor);
    return Offset(r.left + r.width * n.x / 100, r.top + r.height * n.y / 100);
  }

  void reanchor(StyleNode n, String anchor, {Offset? point}) {
    final p = point ?? this.point(n);
    n.anchor = anchor;
    final r = area(n.anchor);
    n.x = ((p.dx - r.left) / r.width * 100);
    n.y = ((p.dy - r.top) / r.height * 100);
  }
}

/// Compare immutable image strings directly, without repeatedly encoding them.
bool styleEquals(StyleDocument? a, StyleDocument? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  bool equal(dynamic x, dynamic y) {
    if (identical(x, y)) return true;
    if (x is Map && y is Map)
      return x.length == y.length &&
          x.keys.every((k) => y.containsKey(k) && equal(x[k], y[k]));
    if (x is List && y is List) {
      if (x.length != y.length) return false;
      for (var i = 0; i < x.length; i++) {
        if (!equal(x[i], y[i])) return false;
      }
      return true;
    }
    return x == y;
  }

  return equal(a.toJson(), b.toJson());
}
