import json
lib_path = 'app/assets/builtins/library.json'
drafts_path = 'app/build/new-presets/drafts.json'
lib = json.load(open(lib_path, encoding='utf-8'))
drafts = json.load(open(drafts_path, encoding='utf-8'))
new = [p for p in drafts['presets'] if p['folder'] == 'classic']
assert len(new) == 27, len(new)
ids = {p['id'] for p in lib['presets']}
assert not ids & {p['id'] for p in new}, '新预设已在内置库中'
# 新款排在“创意边框”分组现有 3 款之后、“手机经典”之前。
last = max(i for i, p in enumerate(lib['presets']) if p['folder'] == 'classic')
lib['presets'][last + 1:last + 1] = new
names = [p['style']['name'] for p in lib['presets']]
assert len(names) == len(set(names)), '预设名称重复'
with open(lib_path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(lib, f, ensure_ascii=False, indent=2)
    f.write('\n')
print('presets:', len(lib['presets']), [p['id'] for p in lib['presets']])
