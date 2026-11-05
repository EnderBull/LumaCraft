/// Management selection is independent from the style already applied to photos.
class PresetSelection {
  final ids = <String>{};
  String? anchor, primary;
  void clear() {
    ids.clear();
    anchor = null;
    primary = null;
  }

  String? choose(String id, List<String> order,
      {bool control = false, bool shift = false}) {
    final had = ids.isNotEmpty;
    if (shift &&
        anchor != null &&
        order.contains(anchor) &&
        order.contains(id)) {
      final a = order.indexOf(anchor!), b = order.indexOf(id);
      if (!control) ids.clear();
      ids.addAll(order.sublist(a < b ? a : b, (a > b ? a : b) + 1));
    } else if (control) {
      if (!ids.add(id)) ids.remove(id);
      anchor = id;
    } else {
      ids
        ..clear()
        ..add(id);
      anchor = id;
    }
    if (!control && !shift || !had && ids.isNotEmpty) {
      primary = (!control && !shift) ? id : order.firstWhere(ids.contains);
      return primary;
    }
    return null;
  }

  String? marquee(Set<String> hits, List<String> order, Set<String> base) {
    ids
      ..clear()
      ..addAll(base)
      ..addAll(hits);
    if (base.isEmpty && hits.isNotEmpty) {
      primary = order.firstWhere(hits.contains);
      anchor = primary;
      return primary;
    }
    return null;
  }
}
