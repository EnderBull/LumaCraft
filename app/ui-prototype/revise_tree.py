from pathlib import Path
p=Path('app/ui-prototype/index.html')
s=p.read_text(encoding='utf-8')
s=s.replace('box-shadow:0 5px 16px #00000028;z-index:5','box-shadow:0 9px 24px #00000060,0 3px 8px #00000040;z-index:5')
a=s.index('<aside class="library">'); b=s.index('</aside>',a)+len('</aside>')
s=s[:a]+'''<aside class="library"><div class="source-heading"><p class="section-label">照片来源</p><label class="subfolder-toggle" title="包含所选目录及其所有子目录中的照片"><input type="checkbox" role="switch" id="includeSubfolders"><span class="switch-track" aria-hidden="true"></span><span>含子目录</span></label></div>
<div id="directoryTree" role="tree" aria-label="电脑目录树"></div>
<div class="divider"></div><p class="section-label">当前位置</p><div class="file-path" id="path"></div><div class="tree-status" id="directoryStatus"></div>
<div class="divider"></div><button class="local-folder-button" id="openfolder">＋ 选择本地目录体验</button><input id="folderinput" type="file" webkitdirectory multiple accept="image/jpeg,image/png" hidden></aside>'''+s[b:]
css='''
.source-heading{display:flex;align-items:center;justify-content:space-between;gap:4px;margin-bottom:19px}
.source-heading .section-label{margin:0;padding:0 0 0 8px;white-space:nowrap}
.subfolder-toggle{display:flex;align-items:center;gap:5px;font-size:10px;color:var(--muted);cursor:pointer;white-space:nowrap;position:relative}
.subfolder-toggle input{position:absolute;width:100%;height:100%;margin:0;opacity:0;cursor:pointer}
.switch-track{display:block;width:24px;height:14px;border-radius:10px;background:var(--line);padding:2px;transition:background .15s}
.switch-track:after{content:'';display:block;width:10px;height:10px;border-radius:50%;background:var(--text);transition:transform .15s}
.subfolder-toggle input:checked+.switch-track{background:var(--accent)}
.subfolder-toggle input:checked+.switch-track:after{transform:translateX(10px);background:var(--ink)}
.subfolder-toggle input:focus-visible+.switch-track{outline:2px solid var(--accent);outline-offset:3px}
.subfolder-toggle:has(input:checked){color:var(--accent)}
.tree-row{display:flex;align-items:center;min-height:32px;border-radius:5px;margin:2px 0;gap:0}
.tree-row.chosen{background:#dfa65315;color:var(--accent)}
.library .tree-row button{margin:0;border-radius:4px;min-width:0;padding:5px 3px}
.library .tree-row .tree-expander{flex:0 0 21px;width:21px;justify-content:center;font-size:14px;color:var(--muted)}
.library .tree-row .tree-name{flex:1;width:auto;gap:7px;overflow:hidden;text-align:left;white-space:nowrap}
.tree-name .node-label{overflow:hidden;text-overflow:ellipsis}
.tree-symbol{font-size:13px;flex:none;color:var(--muted)}
.tree-empty-arrow{flex:0 0 21px}
.tree-count{color:var(--muted);font-size:10px;margin-left:auto;padding-right:5px}
.tree-status{font-size:10px;line-height:1.9;padding:0 10px;color:var(--muted)}
.library .local-folder-button{color:var(--muted);font-size:11px;padding:6px 9px}
.empty-preview{color:var(--muted);font-size:13px;align-self:center;text-align:center;line-height:2}
.light header{box-shadow:0 9px 24px #6a503b33,0 3px 8px #6a503b26}
'''
s=s.replace('</style>',css+'</style>',1)
s=s.replace("let folder=0,photos=[]","let folder='trip',photos=[]")
s=s.replace("const folders=[['川西旅行','2026.10',8],['城市漫步','2026.09',5],['日常记录','2026.08',3]];",'''
const drives=[
 {id:'c',name:'系统 (C:)',path:'C:/',kind:'drive',children:[
   {id:'users',name:'用户',path:'C:/Users',children:[
     {id:'home',name:'当前用户',path:'C:/Users/当前用户',children:[
       {id:'desktop',name:'桌面',path:'C:/Users/当前用户/Desktop',count:0},
       {id:'pictures',name:'图片',path:'C:/Users/当前用户/Pictures',count:3},
       {id:'documents',name:'文档',path:'C:/Users/当前用户/Documents',count:0}]}]},
   {id:'programs',name:'Program Files',path:'C:/Program Files',count:0},
   {id:'windows',name:'Windows',path:'C:/Windows',count:0}]},
 {id:'d',name:'数据 (D:)',path:'D:/',kind:'drive',children:[
   {id:'photo-root',name:'照片',path:'D:/照片',count:0,children:[
     {id:'year2026',name:'2026',path:'D:/照片/2026',children:[
       {id:'trip',name:'川西旅行',path:'D:/照片/2026/川西旅行',count:8,children:[
         {id:'trip-day1',name:'第一天',path:'D:/照片/2026/川西旅行/第一天',count:4},
         {id:'trip-day2',name:'第二天',path:'D:/照片/2026/川西旅行/第二天',count:3}]},
       {id:'city',name:'城市漫步',path:'D:/照片/2026/城市漫步',count:5},
       {id:'daily',name:'日常记录',path:'D:/照片/2026/日常记录',count:3}]},
     {id:'year2025',name:'2025',path:'D:/照片/2025',count:2}]},
   {id:'exports',name:'导出照片',path:'D:/导出照片',count:0}]},
 {id:'e',name:'移动硬盘 (E:)',path:'E:/',kind:'drive',children:[
   {id:'backup',name:'照片备份',path:'E:/照片备份',count:2}]}
];
const directoryNodes=new Map();
const expandedNodes=new Set(['d','photo-root','year2026','trip']);
let includeChildren=false,localSequence=0;
function registerNodes(items){
  for(const node of items){
    node.images=node.images||Array.from({length:node.count||0},(_,i)=>({
      ...newPhoto(i),name:node.id.toUpperCase()+'_'+String(i+1).padStart(4,'0')+'.JPG',directory:node.path}));
    directoryNodes.set(node.id,node);
    if(node.children)registerNodes(node.children);
  }
}
function collectPhotos(node,recursive){
  return [...node.images,...(recursive?(node.children||[]).flatMap(child=>collectPhotos(child,true)):[])];
}
function renderTree(){
  function branch(items,depth){
    return items.map(node=>{
      const open=expandedNodes.has(node.id),hasChildren=!!node.children?.length;
      return '<div role="treeitem" aria-level="'+(depth+1)+'" aria-selected="'+(folder===node.id)+'"'+(hasChildren?' aria-expanded="'+open+'"':'')+'><div class="tree-row '+(folder===node.id?'chosen':'')+'" style="padding-left:'+(depth*10)+'px">'+
        (hasChildren?'<button class="tree-expander" data-expand="'+node.id+'" aria-label="'+(open?'收起':'展开')+' '+escapeHtml(node.name)+'">'+(open?'⌄':'›')+'</button>':'<span class="tree-empty-arrow"></span>')+
        '<button class="tree-name" data-directory="'+node.id+'" aria-label="浏览 '+escapeHtml(node.path)+'"><span class="tree-symbol">'+(node.kind==='drive'?'▤':'▱')+'</span><span class="node-label">'+escapeHtml(node.name)+'</span></button></div>'+
        (hasChildren&&open?'<div role="group">'+branch(node.children,depth+1)+'</div>':'')+'</div>';
    }).join('');
  }
  $('directoryTree').innerHTML=branch(drives,0);
}
''')
a=s.index('function loadFolder('); b=s.index('function render(){',a)
s=s[:a]+'''function loadFolder(id,preserve=false){
  const previous=preserve?photos[current]:null;
  folder=id;
  const node=directoryNodes.get(id);
  photos=collectPhotos(node,includeChildren);
  current=previous?Math.max(0,photos.indexOf(previous)):0;
  anchor=current;
  selected=photos.length?new Set([current]):new Set();
  render();
}
function renderEmpty(){
  $('filename').textContent='暂无照片';$('dimensions').textContent='';$('previewpreset').textContent='';
  $('artboard').className='empty-preview';$('artboard').removeAttribute('style');
  $('artboard').innerHTML=includeChildren?'此目录及子目录中暂无支持的照片':'此目录没有照片<br><span class="tiny">可开启“含子目录”，或选择其他目录</span>';
  $('thumbs').innerHTML='';$('metadata').innerHTML='';
  $('filecount').textContent='0 张照片';$('selectcount').textContent='已选 0 张';
  $('scope').textContent='此目录暂无照片';$('exportcount').textContent='0 张 →';
  $('editinfo').disabled=true;$('export').disabled=true;$('reset').disabled=true;$('newpreset').disabled=true;
  $('caption').disabled=true;$('color').disabled=true;$('sliders').innerHTML='';
  renderPresets();
}
'''+s[b:]
a=s.index("const photo=photos[current],style=activeStyle(photo),config=settings(photo);")
b=s.index("$('filename').textContent=photo.name;",a)
s=s[:a]+"""renderTree();const node=directoryNodes.get(folder);
$('path').textContent=node.path;$('directoryStatus').textContent=(includeChildren?'含全部子目录':'仅当前目录')+' · '+photos.length+' 张照片';
if(!photos.length){renderEmpty();return;}
$('export').disabled=false;$('reset').disabled=false;$('newpreset').disabled=false;$('caption').disabled=false;$('color').disabled=false;
const photo=photos[current],style=activeStyle(photo),config=settings(photo);"""+s[b:]
s=s.replace('function renderPresets(){const query=', 'function renderPresets(){const previewPhoto=photos[current]||newPhoto(0);const query=')
s=s.replace("(photos[current].preset===p.id?'picked':'')","(photos.length&&photos[current].preset===p.id?'picked':'')")
s=s.replace('scene(photos[current])','scene(previewPhoto)')
a=s.index("$('folders').onclick=");b=s.index("$('thumbs').onclick",a)
s=s[:a]+"""$('directoryTree').onclick=e=>{
 const expander=e.target.closest('[data-expand]');
 if(expander){const id=expander.dataset.expand;expandedNodes.has(id)?expandedNodes.delete(id):expandedNodes.add(id);renderTree();return;}
 const directory=e.target.closest('[data-directory]');
 if(directory)loadFolder(directory.dataset.directory);
};
$('includeSubfolders').onchange=e=>{includeChildren=e.target.checked;loadFolder(folder,true);};
"""+s[b:]
s=s.replace("exportScope==='current'?[photos[current]]","exportScope==='current'?(photos.length?[photos[current]]:[])")
s=s.replace("const counts={current:1,", "const counts={current:photos.length?1:0,")
a=s.index("$('openfolder').onclick="); b=s.index("document.addEventListener('keydown'",a)
s=s[:a]+"""$('openfolder').onclick=()=>$('folderinput').click();
$('folderinput').onchange=e=>{
 const files=[...e.target.files].filter(f=>/\\.(jpe?g|png)$/i.test(f.name));
 if(!files.length){toast('请选择包含 JPG 或 PNG 的目录');return;}
 const rootName=files[0].webkitRelativePath.split('/')[0]||'本地照片';
 const root={id:'local-'+(++localSequence),name:rootName,path:rootName,children:[],images:[]};
 const localNodes=new Map([[rootName,root]]);
 for(const file of files){
   const relative=file.webkitRelativePath||rootName+'/'+file.name;
   const parts=relative.split('/');parts.pop();
   let parent=root,path=parts[0];
   for(const part of parts.slice(1)){
     path+='/'+part;
     if(!localNodes.has(path)){
       const child={id:'local-'+(++localSequence),name:part,path,children:[],images:[]};
       localNodes.set(path,child);parent.children.push(child);
     }
     parent=localNodes.get(path);
   }
   parent.images.push({...newPhoto(0,URL.createObjectURL(file)),name:file.name,info:{},directory:parent.path});
 }
 drives.push(root);registerNodes([root]);expandedNodes.add(root.id);loadFolder(root.id);
 toast('本地目录已加入原型目录树，未解析 EXIF');
};
"""+s[b:]
s=s.replace("if(document.querySelector('dialog[open]')||", "if(!photos.length||document.querySelector('dialog[open]')||")
s=s.replace('loadFolder(0);','registerNodes(drives);\nloadFolder(\'trip\');')
p.write_text(s,encoding='utf-8')
