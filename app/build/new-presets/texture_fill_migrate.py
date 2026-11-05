import json
# 0.13.0：纹理改为独立的填充方式。把内置库里“纯色 + 纹理”的预设改写成 mode = texture。
lib_path = 'app/assets/builtins/library.json'
lib = json.load(open(lib_path, encoding='utf-8'))
changed = []
for p in lib['presets']:
    fill = p['style'].get('fill', {})
    if fill.get('texture') and fill.get('mode', 'solid') == 'solid':
        fill['mode'] = 'texture'
        changed.append(p['id'])
    assert not (fill.get('texture') and fill.get('mode') != 'texture'), p['id']
with open(lib_path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(lib, f, ensure_ascii=False, indent=2)
    f.write('\n')
print('changed:', len(changed), changed)
