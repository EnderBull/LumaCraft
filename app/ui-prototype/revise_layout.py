from pathlib import Path
p=Path('app/ui-prototype/index.html')
s=p.read_text(encoding='utf-8')
s=s.replace('--bg:#191c1d;--panel:#222627;--raised:#2b3031;--line:#363c3d;--text:#e4e8e5;--muted:#9aa6a2;--accent:#b6cfb1;--ink:#18241b;--stage:#151819',
'--bg:#1c1b1a;--panel:#262523;--raised:#32302d;--line:#45413b;--text:#ece8e2;--muted:#aaa49a;--accent:#dfa653;--ink:#2a1d0d;--stage:#191817')
s=s.replace('#b6cfb1','#dfa653').replace('#c7dec2','#ebba76')
s=s.replace('--bg:#e9ece8;--panel:#f4f5f1;--raised:#e4e8e1;--line:#d4dad2;--text:#29332e;--muted:#65736a;--accent:#476e48;--ink:white;--stage:#dde1da',
'--bg:#ece8e2;--panel:#f6f3ed;--raised:#e9e2d7;--line:#d7cec0;--text:#393127;--muted:#7c7061;--accent:#9b5e14;--ink:#ffffff;--stage:#e4ded5')
s=s.replace('#587e57','#865014')
s=s.replace('<span class="badge">UI 探索 · 01</span>','')
s=s.replace('<button id="theme"','<button id="layoutButton" class="outline">布局</button><button id="theme"')
s=s.replace('<div class="divider"></div><button id="reference">▧ 样式参考</button><p class="library-note">此原型内置示例照片<br>可用自己的 JPG / PNG<br>体验照片选择与布局</p>','')
s=s.replace("$('reference').onclick=()=>{$('referenceImage').src=reference;$('referenceDialog').showModal();};",'')
start=s.index('<dialog class="modal" id="referenceDialog">')
end=s.index('</dialog>',start)+len('</dialog>')
s=s[:start]+s[end:]
s=s.replace('</header>','<div class="resize resize-header" role="separator" aria-label="调整顶栏高度" aria-orientation="horizontal" tabindex="0" data-resize="top"></div></header>',1)
s=s.replace('</main>','''<div class="resize resize-left" role="separator" aria-label="调整左侧栏宽度" aria-orientation="vertical" tabindex="0" data-resize="left"></div>
<div class="resize resize-right" role="separator" aria-label="调整右侧栏宽度" aria-orientation="vertical" tabindex="0" data-resize="right"></div>
<div class="resize resize-bottom" role="separator" aria-label="调整底栏高度" aria-orientation="horizontal" tabindex="0" data-resize="bottom"></div>
</main>''',1)
css='''
/* 面板层级由局部阴影表达，保留输入框和选择状态的边界。 */
:root{--left:216px;--right:312px;--bottom:172px;--top:61px}
header{position:relative;height:var(--top);background:var(--panel);border:0;box-shadow:0 5px 16px #00000028;z-index:5}
.shell{position:relative;grid-template-columns:var(--left) minmax(430px,1fr) var(--right);grid-template-rows:minmax(240px,1fr) var(--bottom)}
.library{grid-row:1;border:0;box-shadow:7px 0 22px -10px #0009;z-index:2}
.right{grid-row:1;border:0;box-shadow:-7px 0 22px -10px #0009;z-index:2}
.filmstrip{grid-column:1/4;grid-row:2;border:0;position:relative;z-index:3;box-shadow:0 -8px 24px -11px #000b;display:flex;flex-direction:column}
.shell.side-first .library,.shell.side-first .right{grid-row:1/3;z-index:4}
.shell.side-first .filmstrip{grid-column:2}
.film-tools{flex:none;height:37px}
.thumbs{flex:1;min-height:0;height:auto;padding:5px 18px 13px;align-items:stretch}
.thumb{height:100%;min-height:76px;width:auto;aspect-ratio:1.15;display:flex;flex-direction:column}
.thumb .scene{flex:1;min-height:0;height:auto}
.thumb .name{flex:none;gap:10px}
.right-tabs{border:0;box-shadow:0 5px 13px -8px #0009;position:relative;z-index:1}
.divider{background:none;height:0;margin:23px 9px}
.photo-info{border:0;box-shadow:0 -10px 18px -18px #000c;padding-top:23px}
.export-dock{border:0;box-shadow:0 -8px 18px -15px #000b}
footer{border:0;background:var(--panel)}
.scope{border:0;background:#dfa65312}
.outline,.info-button,.new-preset,.filters button{border-color:transparent;background:var(--raised)}
.active{background:#dfa65315}
.filters button.active{color:var(--accent);background:#dfa6531b}
.artboard{width:min(100%,760px,calc((100vh - var(--top) - var(--bottom) - 150px)*1.35))}
.resize{position:absolute;z-index:12;touch-action:none;outline-offset:-2px}
.resize:after{content:'';position:absolute;opacity:0;background:var(--accent);border-radius:5px;transition:opacity .15s}
.resize:hover:after,.resize:focus-visible:after,.resize.dragging:after{opacity:.8}
.resize-left{left:calc(var(--left) - 4px);top:0;width:8px;height:calc(100% - var(--bottom));cursor:col-resize}
.resize-right{right:calc(var(--right) - 4px);top:0;width:8px;height:calc(100% - var(--bottom));cursor:col-resize}
.resize-left:after,.resize-right:after{width:2px;height:44px;left:3px;top:calc(50% - 22px)}
.resize-bottom{left:0;right:0;bottom:calc(var(--bottom) - 4px);height:8px;cursor:row-resize}
.resize-bottom:after,.resize-header:after{height:2px;width:44px;top:3px;left:calc(50% - 22px)}
.resize-header{bottom:-4px;left:0;right:0;height:8px;cursor:row-resize}
.shell.side-first .resize-left,.shell.side-first .resize-right{height:100%}
.shell.side-first .resize-bottom{left:var(--left);right:var(--right)}
.layout-choice{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:22px}
.layout-option{padding:14px;text-align:left;background:var(--raised);border:1px solid transparent}
.layout-option[aria-pressed=true]{border-color:var(--accent);background:#dfa65310}
.layout-diagram{height:82px;display:grid;grid-template-columns:1fr 2fr 1fr;grid-template-rows:1fr 23px;gap:4px;margin-bottom:12px}
.layout-diagram i{display:block;background:var(--line);border-radius:3px}
.layout-diagram .diagram-stage{background:var(--bg)}
.layout-diagram .diagram-film{grid-column:1/4;background:var(--accent);opacity:.75}
.layout-diagram.side-diagram i:first-child,.layout-diagram.side-diagram i:nth-child(3){grid-row:1/3}
.layout-diagram.side-diagram i:nth-child(3){grid-column:3}
.layout-diagram.side-diagram .diagram-film{grid-column:2}
.layout-option small{display:block;color:var(--muted);font-size:10px;margin-top:4px}
.light .library{box-shadow:7px 0 22px -10px #6a503b40}
.light .right{box-shadow:-7px 0 22px -10px #6a503b40}
.light .filmstrip{box-shadow:0 -8px 24px -11px #6a503b55}
@media(max-height:790px){.shell{grid-template-rows:minmax(240px,1fr) var(--bottom)}}
'''
s=s.replace('</style>',css+'</style>',1)
layout_dialog='''<dialog class="modal" id="layoutDialog"><div class="modal-head"><h2>工作台布局</h2><button data-close="layoutDialog" aria-label="关闭布局设置">✕</button></div>
<div class="modal-body"><div class="layout-choice">
<button class="layout-option" data-layout="bottom" aria-pressed="true"><span class="layout-diagram"><i></i><i class="diagram-stage"></i><i></i><i class="diagram-film"></i></span>底栏横向铺满<small>两侧面板位于照片栏上方</small></button>
<button class="layout-option" data-layout="sides" aria-pressed="false"><span class="layout-diagram side-diagram"><i></i><i class="diagram-stage"></i><i></i><i class="diagram-film"></i></span>侧栏纵向铺满<small>照片栏位于两侧面板之间</small></button></div>
<p class="note">拖动面板交界处可调整大小，也可以在这里设置。布局会保存在当前浏览器。</p>
<div class="control"><label for="layout-left">左侧栏宽度 <small id="layout-left-value"></small></label><input type="range" id="layout-left" min="160" max="320" data-size="left"></div>
<div class="control"><label for="layout-right">右侧栏宽度 <small id="layout-right-value"></small></label><input type="range" id="layout-right" min="260" max="420" data-size="right"></div>
<div class="control"><label for="layout-bottom">底栏高度 <small id="layout-bottom-value"></small></label><input type="range" id="layout-bottom" min="132" max="300" data-size="bottom"></div>
<div class="control"><label for="layout-top">顶栏高度 <small id="layout-top-value"></small></label><input type="range" id="layout-top" min="48" max="90" data-size="top"></div></div>
<div class="modal-foot"><button id="resetLayout">恢复默认布局</button><button class="primary" data-close="layoutDialog">完成</button></div></dialog>'''
s=s.replace('<div id="toast"',layout_dialog+'\n<div id="toast"',1)
js='''
const layoutDefaults={mode:'bottom',left:216,right:312,bottom:172,top:61};
let workspaceLayout={...layoutDefaults};
try{const saved=JSON.parse(localStorage.getItem('lumacraft-workspace-layout-v1'));if(saved&&typeof saved==='object')workspaceLayout={...layoutDefaults,...saved};}catch{}
const shell=document.querySelector('.shell');
function applyWorkspaceLayout(){
  const limits={left:[160,Math.max(160,Math.min(320,shell.clientWidth-workspaceLayout.right-430))],
    right:[260,Math.max(260,Math.min(420,shell.clientWidth-workspaceLayout.left-430))],
    bottom:[132,Math.max(132,Math.min(300,shell.clientHeight-240))],top:[48,90]};
  for(const key of ['left','right','bottom','top']){
    const numeric=Number(workspaceLayout[key]);
    workspaceLayout[key]=Math.round(Math.max(limits[key][0],Math.min(limits[key][1],Number.isFinite(numeric)?numeric:layoutDefaults[key])));
    document.documentElement.style.setProperty('--'+key,workspaceLayout[key]+'px');
    $('layout-'+key).value=workspaceLayout[key];
    $('layout-'+key+'-value').textContent=workspaceLayout[key]+' px';
  }
  workspaceLayout.mode=workspaceLayout.mode==='sides'?'sides':'bottom';
  shell.classList.toggle('side-first',workspaceLayout.mode==='sides');
  document.querySelectorAll('[data-layout]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.layout===workspaceLayout.mode)));
  document.querySelectorAll('[data-resize]').forEach(handle=>{
    const key=handle.dataset.resize;
    handle.setAttribute('aria-valuemin',limits[key][0]);handle.setAttribute('aria-valuemax',limits[key][1]);
    handle.setAttribute('aria-valuenow',workspaceLayout[key]);handle.setAttribute('aria-valuetext',workspaceLayout[key]+' 像素');
  });
}
function saveWorkspaceLayout(){try{localStorage.setItem('lumacraft-workspace-layout-v1',JSON.stringify(workspaceLayout));}catch{}}
$('layoutButton').onclick=()=>{applyWorkspaceLayout();$('layoutDialog').showModal();};
document.querySelectorAll('[data-layout]').forEach(button=>button.onclick=()=>{
  workspaceLayout.mode=button.dataset.layout;applyWorkspaceLayout();saveWorkspaceLayout();
});
document.querySelectorAll('[data-size]').forEach(input=>input.oninput=()=>{
  workspaceLayout[input.dataset.size]=Number(input.value);applyWorkspaceLayout();saveWorkspaceLayout();
});
$('resetLayout').onclick=()=>{workspaceLayout={...layoutDefaults};applyWorkspaceLayout();saveWorkspaceLayout();};
document.querySelectorAll('[data-resize]').forEach(handle=>{
  const key=handle.dataset.resize;
  let dragging=false;
  handle.onpointerdown=event=>{if(event.button!==0)return;event.preventDefault();dragging=true;handle.setPointerCapture(event.pointerId);handle.classList.add('dragging');};
  handle.onpointermove=event=>{
    if(!dragging)return;
    const rect=shell.getBoundingClientRect();
    workspaceLayout[key]=key==='left'?event.clientX-rect.left:key==='right'?rect.right-event.clientX:key==='bottom'?rect.bottom-event.clientY:event.clientY-document.querySelector('header').getBoundingClientRect().top;
    applyWorkspaceLayout();
  };
  function finish(){dragging=false;handle.classList.remove('dragging');saveWorkspaceLayout();}
  handle.onpointerup=finish;handle.onpointercancel=finish;handle.onlostpointercapture=finish;
  handle.onkeydown=event=>{
    if(!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(event.key))return;
    event.preventDefault();
    let direction=['ArrowRight','ArrowDown'].includes(event.key)?1:-1;
    if(key==='right'||key==='bottom')direction*=-1;
    workspaceLayout[key]+=direction*(event.shiftKey?20:4);applyWorkspaceLayout();saveWorkspaceLayout();
  };
});
window.addEventListener('resize',applyWorkspaceLayout);
applyWorkspaceLayout();
'''
s=s.replace('loadFolder(0);',js+'\nloadFolder(0);')
p.write_text(s,encoding='utf-8')
