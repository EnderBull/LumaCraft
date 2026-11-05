"""One-shot full copy to a NEW folder, streaming SHA256 + readback verification.
No deletion, overwrite, ZIP, hard-linking or outward junction targets.
"""
import concurrent.futures,datetime,hashlib,json,os,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
HANDOFF=ROOT/'handoff-2026-11-05'
BACKUP=ROOT/'backup-2026-11-05'
DEST=BACKUP/'project'
EVIDENCE=HANDOFF/'evidence'
def digest(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def jsonwrite(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
def enumerate_project():
    files=[];dirs=[];links=[]
    for base,children,names in os.walk(ROOT,followlinks=False):
        base=Path(base)
        if base==ROOT:children[:]=[x for x in children if x not in [HANDOFF.name,BACKUP.name]]
        for name in children[:]:
            item=base/name
            if item.is_symlink() or (hasattr(os.path,'isjunction') and os.path.isjunction(item)):
                target=item.resolve();relative=target.relative_to(ROOT)
                links.append({'path':item.relative_to(ROOT).as_posix(),'original_target':str(target),'backup_target_relative':relative.as_posix(),'directory':True});children.remove(name)
            else:dirs.append(item.relative_to(ROOT).as_posix())
        for name in names:
            item=base/name
            if item.is_symlink():raise RuntimeError('Unexpected file symlink: '+str(item))
            files.append(item.relative_to(ROOT).as_posix())
    return sorted(files),sorted(dirs),links

def copy_new(relative):
    source=ROOT/relative;target=DEST/relative
    before=source.stat();sha=hashlib.sha256();count=0
    target.parent.mkdir(parents=True,exist_ok=True)
    with source.open('rb') as src,target.open('xb') as dst:
        while data:=src.read(4*1024*1024):sha.update(data);dst.write(data);count+=len(data)
    after=source.stat()
    if (before.st_size,before.st_mtime_ns)!=(after.st_size,after.st_mtime_ns) or count!=before.st_size:raise RuntimeError('Source changed while copying: '+relative)
    os.utime(target,ns=(before.st_atime_ns,before.st_mtime_ns))
    if digest(target)!=sha.hexdigest():raise RuntimeError('Backup hash mismatch: '+relative)
    return {'path':relative,'bytes':count,'mtime_ns':before.st_mtime_ns,'sha256':sha.hexdigest()}

def main():
    if BACKUP.exists():raise RuntimeError('Backup target exists; refusing to overwrite it')
    if BACKUP.parent.resolve()!=ROOT or DEST.parent!=BACKUP:raise RuntimeError('Invalid target path')
    files,dirs,links=enumerate_project()
    BACKUP.mkdir();DEST.mkdir()
    start=datetime.datetime.now().astimezone().isoformat()
    jsonwrite(BACKUP/'BACKUP_REPORT.json',{'verified':False,'start':start,'source':str(ROOT),'destination':str(DEST),'status':'copying'})
    for d in dirs:(DEST/d).mkdir(parents=True,exist_ok=True)
    records=[]
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        for record in pool.map(copy_new,files):
            records.append(record)
            if len(records)%4000==0:print('Copied and verified',len(records),'/',len(files),flush=True)
    manifest=EVIDENCE/'PROJECT_SNAPSHOT.jsonl'
    manifest.write_text(''.join(json.dumps(r,ensure_ascii=False)+'\n' for r in records),encoding='utf-8')
    # Retarget the generated plugin junction into this independent backup.
    for link in links:
        target=DEST/link['backup_target_relative'];path=DEST/link['path']
        if not target.is_dir() or path.exists():raise RuntimeError('Unexpected junction path')
        target.resolve().relative_to(DEST.resolve())
        q=lambda s:"'"+str(s).replace("'","''")+"'"
        command='New-Item -ItemType Junction -Path '+q(path)+' -Target '+q(target)+' | Out-Null'
        result=subprocess.run([shutil.which('pwsh') or 'powershell','-NoProfile','-Command',command],capture_output=True,text=True,encoding="utf-8",errors="replace")
        if result.returncode or path.resolve()!=target.resolve():raise RuntimeError('Junction creation failed (may require reparse-point permission): '+(result.stderr or ''))
        link['backup_target']=str(target);link['verified']=True
    # Freeze handoff files after the complete project manifest exists.
    document_files=sorted(p for p in HANDOFF.rglob('*') if p.is_file() and p.name!='HANDOFF_HASHES.json')
    handoff_records=[{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':digest(p)} for p in document_files]
    docmanifest=EVIDENCE/'HANDOFF_HASHES.json';jsonwrite(docmanifest,handoff_records)
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        copied_docs=list(pool.map(copy_new,[p.relative_to(ROOT).as_posix() for p in [*document_files,docmanifest]]))
    for folder in [HANDOFF,*[p for p in HANDOFF.rglob('*') if p.is_dir()]]:(DEST/folder.relative_to(ROOT)).mkdir(parents=True,exist_ok=True)
    report={'verified':True,'start':start,'end':datetime.datetime.now().astimezone().isoformat(),'source':str(ROOT),'destination':str(DEST),'project_files':len(records),'handoff_files':len(copied_docs),'file_bytes':sum(r['bytes'] for r in records+copied_docs),'project_manifest_sha256':digest(manifest),'handoff_manifest_sha256':digest(docmanifest),'source_anchor':json.loads((EVIDENCE/'source-anchor.json').read_text(encoding='utf-8')),'links':links,'excluded':['backup-2026-11-05 (self-recursion prevention)'],'verification':'Every ordinary file was streamed from stable source, then backup bytes reread and SHA256 compared; handoff files checked too. No ZIP or hardlinks. ACL/ADS and external system dependencies are not an image backup.'}
    jsonwrite(BACKUP/'BACKUP_REPORT.json',report)
    print(json.dumps(report,ensure_ascii=False),flush=True)
if __name__=='__main__':
    try:main()
    except Exception as e:
        if BACKUP.exists():jsonwrite(BACKUP/'BACKUP_ERROR.json',{'verified':False,'error':str(e),'time':datetime.datetime.now().astimezone().isoformat()})
        raise
