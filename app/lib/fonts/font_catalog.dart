import 'package:flutter/material.dart';

class ArtworkFont {
  final String id, label, family, asset, category;
  final bool latinOnly;
  const ArtworkFont(this.id, this.label, this.family, this.asset, this.category,
      {this.latinOnly = false});
}

const artworkFonts = <ArtworkFont>[
  ArtworkFont('sourceSans', '思源黑体', 'LCSourceSans',
      'assets/fonts/SourceHanSansCN-Regular.otf', 'sans'),
  ArtworkFont('smiley', '得意黑', 'LCSmiley',
      'assets/fonts/SmileySans-Oblique.ttf', 'sans'),
  ArtworkFont('jost', 'Jost', 'LCJost', 'assets/fonts/Jost.ttf', 'sans',
      latinOnly: true),
  ArtworkFont(
      'manrope', 'Manrope', 'LCManrope', 'assets/fonts/Manrope.ttf', 'sans',
      latinOnly: true),
  ArtworkFont('sourceSerif', '思源宋体', 'LCSourceSerif',
      'assets/fonts/SourceHanSerifCN-Regular.otf', 'serif'),
  ArtworkFont('playfair', 'Playfair Display', 'LCPlayfair',
      'assets/fonts/PlayfairDisplay.ttf', 'serif',
      latinOnly: true),
  ArtworkFont('wenkai', '霞鹜文楷', 'LCWenkai',
      'assets/fonts/LXGWWenKaiLite-Regular.ttf', 'hand'),
  ArtworkFont('caveat', 'Caveat', 'LCCaveat', 'assets/fonts/Caveat.ttf', 'hand',
      latinOnly: true),
];
const legacyFontNames = {
  'sans': '无衬线 · 微软雅黑',
  'serif': '衬线 · Georgia',
  'signature': '手写感 · Georgia Italic'
};
ArtworkFont? artworkFont(String id) =>
    artworkFonts.where((f) => f.id == id).firstOrNull;
bool isKnownArtworkFont(String id) =>
    legacyFontNames.containsKey(id) || artworkFont(id) != null;
Map<String, String> get artworkFontOptions =>
    {for (final f in artworkFonts) f.id: f.label, ...legacyFontNames};
TextStyle artworkTextStyle(String id) {
  final f = artworkFont(id);
  if (f == null && legacyFontNames.containsKey(id)) {
    return TextStyle(
        fontFamily: id == 'sans' ? 'Microsoft YaHei' : 'Georgia',
        fontFamilyFallback: [
          id == 'signature'
              ? 'LCWenkai'
              : id == 'serif'
                  ? 'LCSourceSerif'
                  : 'LCSourceSans'
        ],
        fontStyle: id == 'signature' ? FontStyle.italic : FontStyle.normal);
  }
  return TextStyle(
      fontFamily: f?.family ?? 'LCSourceSans',
      fontFamilyFallback: [
        f?.category == 'serif'
            ? 'LCSourceSerif'
            : f?.category == 'hand'
                ? 'LCWenkai'
                : 'LCSourceSans',
        'Microsoft YaHei'
      ],
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal);
}

String? artworkFontNotice(String id) {
  if (!isKnownArtworkFont(id)) return '缺少字体“$id”，暂用思源黑体显示。';
  final f = artworkFont(id);
  if (f?.latinOnly == true)
    return '英文字体；中文使用${f!.category == 'serif' ? '思源宋体' : f.category == 'hand' ? '霞鹜文楷' : '思源黑体'}回退显示。';
  if (id == 'wenkai') return '使用官方精简版；未收录的生僻字可能回退到其它字体。';
  return null;
}
