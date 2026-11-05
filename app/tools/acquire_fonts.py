"""Download unmodified OFL fonts from official repositories; retain provenance."""
import concurrent.futures, hashlib, io, json, urllib.request, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/fonts'
CACHE=ROOT/'build/font-sources'
DEST.mkdir(parents=True,exist_ok=True); CACHE.mkdir(parents=True,exist_ok=True)
def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'LumaCraft-font-assets'}),timeout=90).read()
def raw(repo,path,ref='main'):return 'https://raw.githubusercontent.com/'+repo+'/'+ref+'/'+path
SOURCES=[
('SourceHanSansCN-Regular.otf',raw('adobe-fonts/source-han-sans','SubsetOTF/CN/SourceHanSansCN-Regular.otf','release'),raw('adobe-fonts/source-han-sans','LICENSE.txt','release')),
('SourceHanSerifCN-Regular.otf',raw('adobe-fonts/source-han-serif','SubsetOTF/CN/SourceHanSerifCN-Regular.otf','release'),raw('adobe-fonts/source-han-serif','LICENSE.txt','release')),
('SmileySans-Oblique.ttf','https://github.com/atelier-anchor/smiley-sans/releases/download/v2.0.1/smiley-sans-v2.0.1.zip',raw('atelier-anchor/smiley-sans','LICENSE')),
('LXGWWenKaiLite-Regular.ttf','https://github.com/lxgw/LxgwWenKai-Lite/releases/download/v1.530/LXGWWenKaiLite-Regular.ttf',raw('lxgw/LxgwWenKai-Lite','OFL.txt')),
*[(name,raw('google/fonts','ofl/'+folder+'/'+remote),raw('google/fonts','ofl/'+folder+'/OFL.txt')) for name,folder,remote in [
('Jost.ttf','jost','Jost%5Bwght%5D.ttf'),('Manrope.ttf','manrope','Manrope%5Bwght%5D.ttf'),('PlayfairDisplay.ttf','playfairdisplay','PlayfairDisplay%5Bwght%5D.ttf'),('Caveat.ttf','caveat','Caveat%5Bwght%5D.ttf')]]]
def download(source):
    name,url,license_url=source
    data=fetch(url)
    if url.endswith('.zip'):
        (CACHE/'smiley-sans-v2.0.1.zip').write_bytes(data)
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            matches=[n for n in z.namelist() if n.endswith('/'+name) or n==name]
            if not matches:raise RuntimeError(str(z.namelist()))
            data=z.read(matches[0])
    if data[:4] not in (b'OTTO',b'\x00\x01\x00\x00'):raise RuntimeError('Invalid font '+name)
    license=fetch(license_url)
    if b'OPEN FONT LICENSE' not in license.upper():raise RuntimeError('Missing OFL '+name)
    (DEST/name).write_bytes(data)
    (DEST/(name.rsplit('.',1)[0]+'-OFL.txt')).write_bytes(license)
    print(name,len(data),flush=True)
    return dict(file=name,url=url,license_url=license_url,bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
if __name__=='__main__':
    with concurrent.futures.ThreadPoolExecutor(8) as pool:records=list(pool.map(download,SOURCES))
    (DEST/'sources.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Total font bytes',sum(r['bytes'] for r in records))
