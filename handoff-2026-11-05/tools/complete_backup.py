"""Finish handoff stage after an interrupted junction step. Never recopy project files."""
from pathlib import Path
import json,hashlib,datetime,concurrent.futures,os
ROOT=Path(__file__).resolve().parents[2];H=ROOT/'handoff-2026-11-05';E=H/'evidence';B=ROOT/'backup-2026-11-05';D=B/'project'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def write(p,j):p.write_text(json.dumps(j,ensure_ascii=False,indent=2),encoding='utf-8')
manifest=E/'PROJECT_SNAPSHOT.jsonl';records=[json.loads(line) for line in manifest.read_text(encoding='utf-8').splitlines()]
assert len(records)==38385,'Project copy was not fully recorded'
for r in records:
    target=D/r['path']
    assert target.is_file() and target.stat().st_size==r['bytes'],r['path']
# Recheck critical state at end of copy, while original copy already reread every file.
for r in json.loads((E/'source-files.json').read_text(encoding='utf-8')):
    assert sha(ROOT/r['path'])==r['sha256'] and sha(D/r['path'])==r['sha256'],r['path']
links=json.loads((E/'after-links.json').read_text(encoding='utf-8'))
for link in links:
    rel=Path(link['target']).relative_to(ROOT);expected=D/rel
    actual=D/link['path']
    assert os.path.isjunction(actual) and actual.resolve()==expected.resolve(),link
    link['backup_target']=str(expected);link['verified']=True
files=sorted(p for p in H.rglob('*') if p.is_file() and p.name!='HANDOFF_HASHES.json')
metadata=[{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in files]
hashfile=E/'HANDOFF_HASHES.json';write(hashfile,metadata)
def copy_new(p):
    target=D/p.relative_to(ROOT);target.parent.mkdir(parents=True,exist_ok=True)
    assert not target.exists(),'Would overwrite: '+str(target)
    with p.open('rb') as src,target.open('xb') as dst:
        while data:=src.read(4*1024*1024):dst.write(data)
    assert sha(target)==sha(p),str(p)
    stat=p.stat();os.utime(target,ns=(stat.st_atime_ns,stat.st_mtime_ns))
with concurrent.futures.ThreadPoolExecutor(8) as pool:list(pool.map(copy_new,[*files,hashfile]))
for p in [H,*[p for p in H.rglob('*') if p.is_dir()]]:(D/p.relative_to(ROOT)).mkdir(parents=True,exist_ok=True)
old=json.loads((B/'BACKUP_REPORT.json').read_text(encoding='utf-8'))
report={'verified':True,'start':old['start'],'end':datetime.datetime.now().astimezone().isoformat(),'source':str(ROOT),'destination':str(D),'project_files':len(records),'handoff_files':len(files)+1,'file_bytes':sum(r['bytes'] for r in records)+sum(p.stat().st_size for p in [*files,hashfile]),'project_manifest_sha256':sha(manifest),'handoff_manifest_sha256':sha(hashfile),'source_anchor':json.loads((E/'source-anchor.json').read_text(encoding='utf-8')),'links':links,'initial_error_preserved':'BACKUP_ERROR.json','excluded':['backup-2026-11-05 (prevent self recursion)'],'verification':'38385 project files: original stable-source streaming hash + independent destination readback completed before the junction step. End recheck: file existence/size plus 149 source/destination critical hashes. Handoff files copied exclusively and each destination SHA256 checked. Junction now targets the independent backup pub-cache. No ZIP, no deletion, no hardlinks. ACL/ADS/external system dependencies not included.'}
write(B/'BACKUP_REPORT.json',report)
print(json.dumps(report,ensure_ascii=False))
