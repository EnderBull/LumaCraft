"""把内置预设里用字符画的短线改成形状组件（一次性转换脚本）。

位置换算依据 measure_test.dart 的实测结果（单位：照片短边 1000 px 坐标系）：
  "——" sourceSans 16：墨迹 25.38 x 1.00，相对文字框中心 dx=+0.03 dy=+2.50
  "▎"   sourceSans 42：墨迹 10.50 x 42.00，相对文字框中心 dx=-15.75 dy=+1.50
"""
import json, sys

path = sys.argv[1]
data = json.load(open(path, encoding='utf-8'))
presets = {p['id']: p for p in data['presets']}


def shape(kind, width, height, color, rotation=0):
    return {
        'kind': kind, 'width': width, 'height': height, 'rotation': rotation,
        'radius': 0, 'skew': 0.25, 'inset': 0.25, 'fill': True, 'split': False,
        'stroke': False, 'pointy': False, 'round': False, 'dashed': False,
        'fillColor': color, 'fillColor2': 0xffb89b6a, 'strokeColor': color,
        'fillOpacity': 100, 'strokeOpacity': 100, 'strokeWidth': 2,
    }


def convert(node, new_shape, x=None, y=None):
    color = node['color']
    node['type'] = 'shape'
    node['text'] = ''
    node['shape'] = new_shape(color)
    if x is not None:
        node['x'] = x
    if y is not None:
        node['y'] = y


gallery = presets['gallery']['style']
bottom_landscape, bottom_portrait = 160, 200  # 底边框 16% / 20%，单位 px
for node in gallery['nodes']:
    if node['id'] in ('gallery-line-left', 'gallery-line-right'):
        assert node['text'] == '——' and node['y'] == 30
        convert(node, lambda c: shape('line', 25.38, 1.0, c),
                y=round((30 / 100 * bottom_landscape + 2.5) / bottom_landscape * 100, 4))
        # 竖图底边框更高，单独换算；其余沿用通用布局。
        gallery['layouts']['portrait']['nodes'][node['id']] = {
            'y': round((30 / 100 * bottom_portrait + 2.5) / bottom_portrait * 100, 4)}

travel = presets['travel']['style']
for node in travel['nodes']:
    if node['id'] == 'travel-accent':
        assert node['text'] == '▎' and node['x'] == 2 and node['y'] == 35
        # 原字符在方图/竖图上左边缘有 1 px 伸出画布被裁掉，可见宽度 9.5 px，
        # 这里按可见部分复刻（中心 4.75 px = 照片宽 1000 px 的 0.475%）；
        # 横图（3:2，宽 1500 px）未被裁，保持 10.5 px，中心 14.25 px = 0.95%。
        convert(node, lambda c: shape('line', 42, 9.5, c, rotation=90),
                x=round(4.75 / 1000 * 100, 4),
                y=round((35 / 100 * 130 + 1.5) / 130 * 100, 4))
        layouts = travel['layouts']
        layouts.setdefault('landscape', {'nodes': {}})
        layouts['landscape'].setdefault('nodes', {})[node['id']] = {
            'x': round(14.25 / 1500 * 100, 4), 'shape': {'height': 10.5}}
        # 竖图：底边框 200 px，原有 y=25；x 沿用通用布局。
        layouts['portrait']['nodes'][node['id']] = {
            'y': round((25 / 100 * 200 + 1.5) / 200 * 100, 4)}
with open(path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')
print('converted')
