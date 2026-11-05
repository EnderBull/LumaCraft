"""Read-only snapshot verification. Does not repair or delete files."""
import argparse,hashlib,json,sys
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);parser.add_argument('--scope',choices=['source','project','handoff'],default='source');args=parser.parse_args()
root=args.root.resolve();evidence=root/'handoff-2026-11-05/evidence'
if args.scope=='source':entries=json.loads((evidence/'source-files.json').read_text(encoding='utf-8'))
elif args.scope=='project':entries=[json.loads(line) for line in (evidence/'PROJECT_SNAPSHOT.jsonl').read_text(encoding='utf-8').splitlines()]
else:entries=json.loads((evidence/'HANDOFF_HASHES.json').read_text(encoding='utf-8'))
failures=[]
for entry in entries:
    path=root/entry['path']
    try:
        with path.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
        if digest!=entry['sha256']:failures.append({'path':entry['path'],'reason':'sha256 mismatch'})
    except Exception as e:failures.append({'path':entry['path'],'reason':str(e)})
print(json.dumps({'scope':args.scope,'root':str(root),'checked':len(entries),'failures':failures},ensure_ascii=False))
sys.exit(1 if failures else 0)
