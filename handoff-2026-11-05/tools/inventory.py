import os,json,hashlib,collections,datetime,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'handoff-2026-11-05/evidence'
phase=sys.argv[1] if len(sys.argv)>1 else 'before'
files=[];dirs=[];links=[];errors=[];totals=collections.defaultdict(lambda:[0,0]);key=[]
exclude={'handoff-2026-11-05','backup-2026-11-05'}
for base,children,names in os.walk(ROOT,followlinks=False,onerror=lambda e:errors.append(str(e))):
    folder=Path(base);rel=folder.relative_to(ROOT)
    if folder==ROOT:children[:]=[n for n in children if n not in exclude]
    for name in children[:]:
        item=folder/name
        if item.is_symlink() or (hasattr(os.path,'isjunction') and os.path.isjunction(item)):
            links.append({'path':item.relative_to(ROOT).as_posix(),'target':str(item.resolve()),'directory':True})
            children.remove(name)
        else:dirs.append(item.relative_to(ROOT).as_posix())
    for name in sorted(names):
        item=folder/name;name=item.relative_to(ROOT).as_posix()
        try:
            st=item.stat();entry={'path':name,'bytes':st.st_size,'mtime_ns':st.st_mtime_ns}
            if item.is_symlink():links.append({'path':name,'target':str(item.resolve()),'directory':False})
            files.append(entry)
            group='/'.join(name.split('/')[:2]) if '/' in name else '[root]'
            totals[group][0]+=1;totals[group][1]+=st.st_size
            if (not '/' in name or name.startswith(('app/lib/','app/test/','app/tools/','app/windows/runner/','app/windows/CMakeLists','app/android/app/src/','app/assets/')) or name in ['app/pubspec.yaml','app/pubspec.lock','app/test/core/pubspec.yaml','app/test/core/pubspec.lock','app/analysis_options.yaml','app/android/app/build.gradle.kts','app/android/settings.gradle.kts']):
                key.append(dict(entry,sha256=hashlib.file_digest(item.open('rb'),'sha256').hexdigest()))
        except Exception as e:errors.append({'path':name,'error':str(e)})
files.sort(key=lambda x:x['path']);key.sort(key=lambda x:x['path']);dirs.sort()
for suffix,data in [('files',files),('dirs',dirs),('links',links),('key-hashes',key),('errors',errors)]:
    (OUT/(phase+'-'+suffix+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
summary={'time':datetime.datetime.now().astimezone().isoformat(),'files':len(files),'bytes':sum(x['bytes'] for x in files),'dirs':len(dirs),'links':len(links),'key_files':len(key),'errors':errors,'groups':dict(totals)}
(OUT/(phase+'-summary.json')).write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False))
