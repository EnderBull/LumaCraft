import json
lib_path = 'app/assets/builtins/library.json'
drafts_path = 'app/build/phone-preview/drafts.json'
lib = json.load(open(lib_path, encoding='utf-8'))
drafts = json.load(open(drafts_path, encoding='utf-8'))
assert not [p for p in lib['presets'] if p['folder'] == 'phone'], 'phone 分组应为空'
lib['presets'].extend(drafts['presets'])
names = [p['style']['name'] for p in lib['presets']]
assert len(names) == len(set(names))
with open(lib_path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(lib, f, ensure_ascii=False, indent=2)
    f.write('\n')
print('presets:', len(lib['presets']), [p['id'] for p in lib['presets']])
