'use strict';
const $ = id => document.getElementById(id);
const copy = value => JSON.parse(JSON.stringify(value));
const esc = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const clamp = (n, min, max) => Math.min(max, Math.max(min, Number.isFinite(+n) ? +n : min));
const icons = {
  search:'M17 10a7 7 0 1 1-14 0 7 7 0 0 1 14 0m-2 5 6 6',
  plus:'M12 5v14M5 12h14', close:'m6 6 12 12M18 6 6 18', chevronDown:'m7 10 5 5 5-5',
  undo:'M8 5 3 10l5 5M3 10h10a7 7 0 0 1 7 7', redo:'m16 5 5 5-5 5M21 10h-10a7 7 0 0 0-7 7',
  restore:'M4 5v6h6M4 11a8 8 0 1 1 1 7', arrowUp:'m7 10 5-5 5 5M12 5v14', arrowDown:'m7 14 5 5 5-5M12 5v14', arrowRight:'M4 12h16m-6-6 6 6-6 6',
  text:'M5 5h14M12 5v14M8 19h8', author:'M5 18 16 5l3 3L8 21H4v-4M14 7l3 3',
  params:'M4 7h16M4 12h12M4 17h16', camera:'M3 8h4l2-3h6l2 3h4v12H3ZM16 14a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
  lens:'M20 12a8 8 0 1 1-16 0 8 8 0 0 1 16 0M16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0',
  time:'M20 12a8 8 0 1 1-16 0 8 8 0 0 1 16 0M12 7v5l3 2', location:'M18 10c0 5-6 11-6 11S6 15 6 10a6 6 0 1 1 12 0ZM14 10a2 2 0 1 1-4 0 2 2 0 0 1 4 0',
  eye:'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12ZM15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0',
  eyeOff:'m3 3 18 18M9 5c7-2 13 7 13 7a23 23 0 0 1-4 4M6 6a24 24 0 0 0-4 6s5 9 13 6',
  lock:'M5 11h14v10H5ZM8 11V7a4 4 0 0 1 8 0v4M12 15v2', unlock:'M5 11h14v10H5ZM8 11V7a4 4 0 0 1 7-3',
  duplicate:'M8 8h12v12H8ZM4 16V4h12', trash:'M4 6h16M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7m4-7v7',
  save:'M4 3h13l4 4v14H3V3ZM7 3v6h10V3M7 21v-8h10v8',
  sliders:'M4 6h7m4 0h5M11 3v6M4 12h2m4 0h10M6 9v6M4 18h10m4 0h2M14 15v6',
  folder:'M3 6V4h7l2 3h9v13H3ZM3 10h18', landscape:'M3 5h18v14H3Z', portrait:'M6 3h12v18H6Z', square:'M4 4h16v16H4Z',
  bottomLayout:'M3 3h18v18H3ZM3 16h18M8 3v13m8-13v13', sideLayout:'M3 3h18v18H3ZM8 3v18M16 3v18M8 16h8',
  info:'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0M12 11v6M12 7v.1',
  help:'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0M9 9a3 3 0 0 1 6 0c0 2-3 2-3 5M12 17v.1',
  alignLeft:'M4 4v16M7 7h13M7 12h9M7 17h13', alignCenter:'M12 3v18M4 7h16M7 12h10M4 17h16', alignRight:'M20 4v16M4 7h13M8 12h9M4 17h13'
};
function icon(name) { return `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><path d="${icons[name] || icons.text}"/></svg>`; }
function fillIcons(root=document) { root.querySelectorAll('[data-icon]').forEach(el => el.innerHTML=icon(el.dataset.icon)); }
const typeNames={text:'自由文字',author:'作者签名',params:'拍摄参数',camera:'相机型号',lens:'镜头型号',time:'拍摄时间',location:'拍摄地点'};
const fonts={serif:'Georgia, "SimSun", serif',sans:'"Microsoft YaHei UI", "Microsoft YaHei", sans-serif',signature:'Georgia, serif'};
const fontNames={serif:'衬线 · Georgia',sans:'无衬线 · 微软雅黑',signature:'手写感 · Georgia Italic'};
function makeNode(type='text',id=crypto.randomUUID()) {
  return {id,type,name:typeNames[type],text:type==='author'?'Alex Chen':'新的文字',anchor:'bottom',x:50,y:50,fontSize:24,font:'sans',color:'#544c41',opacity:100,spacing:0,align:'center',visible:true,locked:false};
}
function template(kind='gallery') {
  const title={...makeNode('text','title'),name:'题签',text:'MOUNTAIN SILENCE',font:'serif',fontSize:32,spacing:4,y:32,color:'#34312a'};
  const params={...makeNode('params','parameters'),x:39,y:76,fontSize:14,spacing:1,color:'#8a847a'};
  const author={...makeNode('author','signature'),x:78,y:76,font:'signature',fontSize:25,color:'#686157'};
  const doc={name:kind==='blank'?'空白预设':kind==='film'?'胶片档案':'画廊签名',template:kind,borders:{top:3,right:3,bottom:16,left:3},linked:false,background:'#f3f0e8',nodes:kind==='blank'?[]:[title,params,author]};
  if(kind==='film') {doc.background='#121212';doc.borders={top:3,right:2,bottom:13,left:2};doc.nodes.forEach(n=>{n.color='#c4a56c';n.align='left';n.x=5;});title.fontSize=27;title.spacing=2;params.y=74;author.x=77;}
  return ensureObjectTree(doc);
}
function normaliseDoc(raw) {
  if(!raw || !raw.borders || !Array.isArray(raw.nodes)) throw Error('草稿格式不完整');
  const out=template(['gallery','film','blank'].includes(raw.template)?raw.template:'gallery');
  out.name=String(raw.name||out.name).slice(0,80);
  for(const key of Object.keys(out.borders))out.borders[key]=clamp(raw.borders[key],0,40);
  out.linked=!!raw.linked;
  if(/^#[\da-f]{6}$/i.test(raw.background))out.background=raw.background;
  const seen=new Set();
  out.nodes=raw.nodes.slice(0,80).map(n=>{
    const a=makeNode(Object.hasOwn(typeNames,n.type)?n.type:'text');
    if(typeof n.id==='string' && !seen.has(n.id))a.id=n.id;seen.add(a.id);
    a.name=String(n.name||a.name).slice(0,80);a.text=String(n.text??a.text).slice(0,1000);
    a.anchor=['canvas','photo','bottom'].includes(n.anchor)?n.anchor:'bottom';
    a.x=clamp(n.x,0,100);a.y=clamp(n.y,0,100);a.fontSize=clamp(n.fontSize,8,110);
    a.font=Object.hasOwn(fonts,n.font)?n.font:'sans';a.opacity=clamp(n.opacity??100,0,100);a.spacing=clamp(n.spacing??0,0,15);
    a.align=['left','center','right'].includes(n.align)?n.align:'center';a.visible=n.visible!==false;a.locked=!!n.locked;
    if(/^#[\da-f]{6}$/i.test(n.color))a.color=n.color;return a;
  });
  out.groups=Array.isArray(raw.groups)?copy(raw.groups):[];
  out.order=Array.isArray(raw.order)?copy(raw.order):undefined;
  return ensureObjectTree(out);
}
const baseMetadata={camera:'FUJIFILM X-T5',lens:'XF 23mm F1.4 R LM WR',focal:'35 mm',aperture:'f/2.8',shutter:'1/250 s',iso:'ISO 200',time:'2026.10.18 06:49',location:'川西 · 四姑娘山'};
const photos=Array.from({length:8},(_,i)=>({name:`DSC_${2041+i}.JPG`,ratio:i===2||i===5?2/3:i===6?1:1.5,filter:['none','brightness(.94) saturate(.88)','saturate(.76)','brightness(1.08)','saturate(.9) brightness(.9)','brightness(1.05) saturate(.8)','saturate(.65)','brightness(.92)'][i],metadata:{...baseMetadata,shutter:i%2?'1/500 s':'1/250 s',iso:`ISO ${i%2?400:200}`,location:i===3?'':baseMetadata.location},applied:null}));
let doc=template(),entryDoc=copy(doc),selectedNode=null,current=0,selectedPhotos=new Set([0]),photoAnchor=0,preview='original',leftTab='layers';
let rightPanel='presets',presetFilter='all',presetQuery='',inlineEdit=null,lastCanvasHit=null,lastCanvasClick=null,ignoreLayerClickUntil=0;
let settings={layout:'bottom',left:220,right:310,bottom:150},presets=[],undoStack=[],redoStack=[],pending=null,drag=null,guide=false,saveTimer,toastTimer,storageError=false;
let savePresetTarget=null,saveNewPresetName='';
const draftKey='lumacraft-editor-draft-v1',presetsKey='lumacraft-editor-presets-v1';
function load() {
  try {
    const saved=JSON.parse(localStorage.getItem(draftKey)||'null');
    if(saved?.version===1){doc=normaliseDoc(saved.doc);current=Math.round(clamp(saved.current,0,7));selectedPhotos=new Set((saved.selectedPhotos||[current]).filter(i=>Number.isInteger(i)&&i>=0&&i<8));photoAnchor=current;
      if(saved.applied)photos.forEach((p,i)=>{if(saved.applied[i])p.applied=normaliseDoc(saved.applied[i]);});
      if(saved.settings)settings={layout:saved.settings.layout==='side'?'side':'bottom',snap:saved.settings.snap!==false,left:clamp(saved.settings.left,180,300),right:clamp(saved.settings.right,280,400),bottom:clamp(saved.settings.bottom,125,260)};
    }
    const stored=JSON.parse(localStorage.getItem(presetsKey)||'[]');
    if(Array.isArray(stored))presets=stored.map(p=>({id:String(p.id),name:String(p.name).slice(0,80),doc:normaliseDoc(p.doc)}));
  } catch(e) {storageError=true;setTimeout(()=>toast('本地记录无法读取，本次以可用草稿继续。'),300);}
  entryDoc=copy(doc);
}
function persist() {
  clearTimeout(saveTimer);saveTimer=setTimeout(()=>{
    try {localStorage.setItem(draftKey,JSON.stringify({version:1,doc,current,selectedPhotos:[...selectedPhotos],settings,applied:photos.map(p=>p.applied)}));storageError=false;$('draftState').textContent='草稿已保存';$('storageStatus').textContent='草稿仅保存在此浏览器';}
    catch(e){storageError=true;$('draftState').textContent='草稿未保存';$('storageStatus').textContent='本地保存失败，请勿关闭此页';toast('浏览器本地存储不可用，草稿暂存于本次页面。');}
  },250);
}
function toast(message) {$('toast').textContent=message;$('toast').hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('toast').hidden=true,3200);}
function node() {return doc.nodes.find(n=>n.id===selectedNode);}
function snapshotEqual(a,b) {return JSON.stringify(a)===JSON.stringify(b);}
function checkpoint(before) {if(snapshotEqual(before,doc))return;undoStack.push(before);if(undoStack.length>60)undoStack.shift();redoStack=[];updated();}
function edit(action) {finishEdit();ensureObjectTree(doc);const before=copy(doc);action();ensureObjectTree(doc);checkpoint(before);render();}
function finishEdit() {if(pending){const before=pending;pending=null;checkpoint(before);}}
function updated() {$('draftState').textContent='正在保存…';persist();renderHeader();}
function history(direction) {finishEdit();const from=direction==='undo'?undoStack:redoStack,to=direction==='undo'?redoStack:undoStack;if(!from.length)return;to.push(copy(doc));doc=from.pop();if(!entity(selectedNode))selectedNode=null;updated();render();}
function geometry() {
  const ratio=preview==='original'?photos[current].ratio:preview==='landscape'?1.5:preview==='portrait'?2/3:1;
  const pw=ratio>=1?1000*ratio:1000,ph=ratio>=1?1000:1000/ratio;
  const b=Object.fromEntries(Object.entries(doc.borders).map(([k,v])=>[k,v*10]));
  return {pw,ph,b,w:pw+b.left+b.right,h:ph+b.top+b.bottom};
}
function anchorRect(n,g=geometry()) {return n.anchor==='photo'?{x:g.b.left,y:g.b.top,w:g.pw,h:g.ph}:n.anchor==='bottom'?{x:0,y:g.b.top+g.ph,w:g.w,h:g.b.bottom}:{x:0,y:0,w:g.w,h:g.h};}
function nodePoint(n,g=geometry()) {const a=anchorRect(n,g);return{x:a.x+a.w*n.x/100,y:a.y+a.h*n.y/100};}
function content(n) {const meta=photos[current].metadata;if(n.type==='text'||n.type==='author')return n.text;return n.type==='params'?[meta.focal,meta.aperture,meta.shutter,meta.iso].filter(Boolean).join('   /   '):meta[n.type]||'';}
function sceneSvg(filter='none') {return `<svg viewBox="18 150 487 314" preserveAspectRatio="xMidYMid slice" style="filter:${filter}"><image href="../reference.png" width="1536" height="1024"/></svg>`;}
function renderCanvas() {
  const g=geometry(),svg=$('artboard');svg.setAttribute('viewBox',`0 0 ${g.w} ${g.h}`);svg.setAttribute('width','100%');svg.setAttribute('height','100%');
  let html=`<rect width="${g.w}" height="${g.h}" fill="${doc.background}"/><svg x="${g.b.left}" y="${g.b.top}" width="${g.pw}" height="${g.ph}" viewBox="18 150 487 314" preserveAspectRatio="xMidYMid slice" overflow="hidden" style="filter:${photos[current].filter}"><image href="../reference.png" width="1536" height="1024"/></svg>`;
  for(const n of doc.nodes){if(!objectVisible(n.id)||!content(n)||(n.anchor==='bottom'&&!g.b.bottom))continue;const p=nodePoint(n,g);
    html+=`<g data-node="${esc(n.id)}" data-locked="${objectLocked(n.id)}" opacity="${inlineEdit?.id===n.id?0:1}"><text x="${p.x}" y="${p.y}" text-anchor="${n.align==='left'?'start':n.align==='right'?'end':'middle'}" dominant-baseline="central" font-family='${esc(fonts[n.font])}' font-size="${n.fontSize}" fill="${n.color}" fill-opacity="${n.opacity/100}" letter-spacing="${n.spacing}" font-style="${n.font==='signature'?'italic':'normal'}">${content(n).split(/\r?\n/).map((line,i,lines)=>`<tspan x="${p.x}" dy="${i===0?-(lines.length-1)*n.fontSize*.7:n.fontSize*1.4}">${esc(line)||' '}</tspan>`).join('')}</text></g>`;
  }
  svg.innerHTML=html;
  drawObjectSelection();
}
function renderHeader() {
  syncObjectSelection();
  $('documentName').textContent=doc.name+' · 编辑草稿';$('undo').disabled=!undoStack.length&&!pending;$('redo').disabled=!redoStack.length;
  $('photoName').textContent=photos[current].name;$('photoDetails').textContent=photos[current].ratio<1?'竖向构图':photos[current].ratio===1?'方形构图':'横向构图';
  $('selectionCount').textContent=`已选 ${selectedPhotos.size} 张`;
  const applied=photos[current].applied&&snapshotEqual(doc,photos[current].applied);
  $('previewBadge').innerHTML=`<span class="status-dot"></span>${applied?'当前照片已应用此样式':'草稿预览 · 尚未应用'}`;
  $('footerStatus').textContent=node()?`${node().name} · ${typeNames[node().type]}`:'演示照片 · 交互原型';
  for(const el of document.querySelectorAll('[data-layout]')){el.classList.toggle('active',el.dataset.layout===settings.layout);el.setAttribute('aria-pressed',el.dataset.layout===settings.layout);}
  for(const el of document.querySelectorAll('[data-preview]')){el.classList.toggle('active',el.dataset.preview===preview);el.setAttribute('aria-pressed',el.dataset.preview===preview);}
  renderObjectControls();
}
function renderLayers() {renderObjectLayers();}

const field=(label,body)=>`<label class="property-label">${label}</label>${body}`;
const numeric=(key,value,min,max,unit='')=>`<div class="number-field"><input data-prop="${key}" aria-label="${({x:'水平位置',y:'垂直位置',fontSize:'字号',spacing:'字间距',opacity:'不透明度'})[key]||key}" type="number" value="${Math.round(value*10)/10}" min="${min}" max="${max}" step="${key==='fontSize'?1:.1}"><span>${unit}</span></div>`;
function renderProperties() {
  renderInspectorTabs();
  if(rightPanel==='presets'){renderPresets();return;}
  if(rightPanel==='component'&&(objectSelection.size>1||entity(selectedNode)?.children)){renderObjectProperties();return;}
  const n=rightPanel==='component'?node():null;let html='';
  if(rightPanel==='component'&&!n){$('properties').innerHTML=`<div class="component-empty">${icon('text')}<div>先选择一个组件</div><p class="hint">点击画布文字或左侧图层，再调整它的样式。</p><button id="propertiesAdd" class="neutral" style="margin-top:15px">${icon('plus')}添加组件</button></div>`;return;}
  if(!n){html=`<section class="property-section"><div class="property-title">边框<span class="muted">照片短边比例</span></div><label class="toggle"><input id="linked" type="checkbox" ${doc.linked?'checked':''}>四边联动</label><div class="field-grid">${Object.entries({top:'上',bottom:'下',left:'左',right:'右'}).map(([key,label])=>`<label><span class="property-label">${label}</span><div class="number-field"><input type="number" data-border="${key}" aria-label="${label}边框比例" min="0" max="40" step=".5" value="${doc.borders[key]}"><span>%</span></div></label>`).join('')}</div><p class="hint">四边为 0 时，组件可叠加在照片上。</p></section><section class="property-section"><div class="property-title">背景填充<span class="muted">纯色</span></div><div class="color-row"><input aria-label="背景颜色" type="color" data-canvas-color value="${doc.background}"><input data-canvas-hex aria-label="背景色值" value="${doc.background.toUpperCase()}" maxlength="7"></div><div class="swatches">${['#f3f0e8','#ffffff','#121212','#263238','#d9d2c5','#49504a'].map(c=>`<button data-swatch="${c}" class="color-swatch" style="background:${c}" title="背景 ${c}" aria-label="背景 ${c}"></button>`).join('')}</div></section><section class="property-section"><div class="property-title">创建组件</div><p class="hint">让文字与照片一起讲述。固定文字随预设保存，拍摄参数跟随每张照片。</p><button id="propertiesAdd" class="neutral" style="width:100%;margin-top:14px">${icon('plus')}添加组件</button></section>`;
  }else{
    html=`<section class="property-section"><div class="property-title"><span>${typeNames[n.type]}</span><span class="muted">${n.locked?'已锁定':n.visible?'显示中':'已隐藏'}</span></div>${field('图层名称',`<input data-prop="name" aria-label="图层名称" value="${esc(n.name)}" maxlength="80">`)}${n.type==='text'||n.type==='author'?field('内容',`<textarea data-prop="text" aria-label="文字内容" maxlength="1000">${esc(n.text)}</textarea>`):`<label class="property-label">当前照片提供的内容</label><div class="hint ${!content(n)?'missing':''}">${esc(content(n)||'缺失：此组件在当前照片上自动隐藏')}</div><p class="hint">来自照片信息，无需逐张输入。</p>`}</section>`;
    html+=`<section class="property-section"><div class="property-title">文字样式</div>${field('字体',`<select data-prop="font" aria-label="字体">${Object.entries(fontNames).map(([key,name])=>`<option value="${key}" ${n.font===key?'selected':''}>${name}</option>`).join('')}</select>`)}<div class="field-grid"><label><span class="property-label">字号</span>${numeric('fontSize',n.fontSize,8,110,'px')}</label><label><span class="property-label">字间距</span>${numeric('spacing',n.spacing,0,15,'px')}</label></div><p class="hint">以照片短边 1000 px 为基准，等比例缩放。</p><label class="property-label">颜色</label><div class="color-row"><input type="color" data-prop="color" aria-label="文字颜色" value="${n.color}"><input data-prop="colorHex" aria-label="文字色值" value="${n.color.toUpperCase()}" maxlength="7"></div>${field('对齐',`<div class="button-group">${['left','center','right'].map(a=>`<button data-align="${a}" class="${n.align===a?'active':''}" title="${{left:'左对齐',center:'居中',right:'右对齐'}[a]}" aria-label="${{left:'左对齐',center:'居中',right:'右对齐'}[a]}">${icon('align'+a[0].toUpperCase()+a.slice(1))}</button>`).join('')}</div>`)}<label class="inline-label" style="margin-top:15px">不透明度<span id="opacityValue">${Math.round(n.opacity)}%</span></label><input type="range" data-prop="opacity" aria-label="不透明度" min="0" max="100" value="${n.opacity}"></section>`;
    html+=`<section class="property-section"><div class="property-title">位置与锚点</div>${field('相对区域',`<select data-prop="anchor" aria-label="相对区域">${Object.entries({bottom:'下边框',photo:'照片区域',canvas:'整个画布'}).map(([key,label])=>`<option value="${key}" ${n.anchor===key?'selected':''}>${label}</option>`).join('')}</select>`)}<div class="field-grid"><label><span class="property-label">X · 水平</span>${numeric('x',n.x,0,100,'%')}</label><label><span class="property-label">Y · 垂直</span>${numeric('y',n.y,0,100,'%')}</label></div><p class="hint">切换区域时自动换算坐标，尽量保持位置。Alt 临时关闭拖动吸附。</p></section><section class="property-section node-actions"><button id="duplicateNode" class="neutral" title="复制 Ctrl+J">${icon('duplicate')}复制</button><button id="deleteNode" class="neutral danger" ${n.locked?'disabled':''}>${icon('trash')}删除</button></section>`;
  }
  $('properties').innerHTML=html;
  if(n&&rightPanel==='component')$('properties').insertAdjacentHTML('beforeend',`<section class="property-section"><div class="property-title">组件对齐<span class="muted">相对画布</span></div>${alignmentButtons()}</section>`);
  if(n&&objectLocked(n.id))$('properties').querySelectorAll('input,textarea,select,[data-align]').forEach(el=>el.disabled=true);
}
function renderPhotos(){const scroll=$('thumbnails').scrollLeft;$('thumbnails').innerHTML=photos.map((p,i)=>`<button class="thumbnail ${selectedPhotos.has(i)?'selected':''} ${current===i?'current':''}" data-photo="${i}" aria-label="选择照片 ${p.name}" aria-pressed="${selectedPhotos.has(i)}"><div class="thumb-photo">${sceneSvg(p.filter)}</div><span>${p.name}</span>${p.applied?'<i class="applied-dot" title="已应用样式"></i>':''}</button>`).join('');$('thumbnails').scrollLeft=scroll;}
function render(){syncObjectSelection();renderHeader();renderLayers();renderProperties();renderCanvas();renderPhotos();}
function selectNode(id){finishEdit();setObjectSelection(id?[id]:[],id);}

function applyLayout(){const root=$('workspace');settings.right=clamp(settings.right,280,Math.max(280,Math.min(400,root.clientWidth-settings.left-440)));settings.left=clamp(settings.left,180,Math.max(180,Math.min(300,root.clientWidth-settings.right-440)));root.classList.toggle('side',settings.layout==='side');for(const key of ['left','right','bottom'])root.style.setProperty('--'+key,settings[key]+'px');renderHeader();}
function add(type){edit(()=>{const n=makeNode(type);if(!doc.borders.bottom)n.anchor='photo';doc.nodes.push(n);selectedNode=n.id;rightPanel='component';});$('popover').hidden=true;toast(`已添加${typeNames[type]}，可在画布拖动`);}
function popover(anchor,items){const box=$('popover');box.innerHTML=items.map(item=>item.heading?`<small>${esc(item.heading)}</small>`:`<button data-menu-action="${item.action}">${item.layerIcon?layerIcon(item.icon||'text'):icon(item.icon||'text')}${esc(item.label)}</button>`).join('');box.hidden=false;const r=anchor.getBoundingClientRect();box.style.left=Math.min(r.left,innerWidth-245)+'px';box.style.top=Math.min(r.bottom+7,innerHeight-box.offsetHeight-15)+'px';}
function addMenu(anchor){popover(anchor,[{heading:'添加到当前画布'},...Object.entries(typeNames).map(([key,label])=>({label,icon:key,layerIcon:true,action:'add:'+key}))]);}
function modal(title,body,actions){$('modal').classList.remove('preset-save-dialog');$('modalTitle').textContent=title;$('modalBody').innerHTML=body;$('modalActions').innerHTML=actions;$('modal').showModal();}
function closeModal(){$('modal').close();}
function choosePreset(){finishEdit();switchInspector('presets');}

function applyDialog(){finishEdit();modal('应用样式',`<p class="hint">将当前草稿应用到明确选择的照片。其他照片的样式保持原样。</p><label class="choice"><input type="radio" name="applyScope" value="current" ${selectedPhotos.size<=1?'checked':''}><span>仅当前照片<small>${esc(photos[current].name)}</small></span><b>1 张</b></label><label class="choice"><input type="radio" name="applyScope" value="selected" ${selectedPhotos.size>1?'checked':''} ${!selectedPhotos.size?'disabled':''}><span>选中照片<small>使用底部缩略图调整选择范围</small></span><b>${selectedPhotos.size} 张</b></label>`,`<button type="button" data-close>取消</button><button class="primary" type="submit" data-confirm="apply">确认应用</button>`);}
function savePresetOptions(){
  return `<button type="button" class="save-target selected" data-save-target="" aria-label="新建预设" aria-pressed="true"><span class="save-target-preview"><span class="save-new-mark">${layerIcon('add')}</span></span><b>新建预设</b><small>保存为新的样式</small></button>`+
    presets.map(p=>`<button type="button" class="save-target" data-save-target="${esc(p.id)}" aria-label="覆盖预设 ${esc(p.name)}" aria-pressed="false"><span class="save-target-preview">${presetPreview(p.doc)}</span><b>${esc(p.name)}</b><small>选择后覆盖保存</small></button>`).join('');
}
function saveDialog(){
  finishEdit();savePresetTarget=null;saveNewPresetName=(doc.name+' · 我的版本').slice(0,60);
  modal('保存预设',`<p class="hint">新建预设，或选择一个用户预设进行覆盖。</p><div class="save-section-heading"><span>用户预设</span><span>${presets.length} 个用户预设</span></div><div class="save-preset-grid">${savePresetOptions()}</div><label class="save-name-label" for="presetName">预设名称</label><input id="presetName" required maxlength="60" value="${esc(saveNewPresetName)}"><div id="saveModeNote" class="save-mode-note">将<strong>新建一个用户预设</strong>。保存后可在“我的”中找到。</div><p class="hint">保存组件、排版与固定文字；照片参数跟随每张照片。保存不会自动应用到照片。</p>`,
    `<button type="button" data-close>取消</button><button id="confirmPresetSave" class="primary" type="submit" data-confirm="save">新建保存</button>`);
  $('modal').classList.add('preset-save-dialog');
}
function selectPresetSaveTarget(id){
  if(savePresetTarget===null)saveNewPresetName=$('presetName').value;
  const target=id?presets.find(p=>p.id===id):null;
  if(id&&!target)return;
  savePresetTarget=target?.id||null;
  $('modalBody').querySelectorAll('[data-save-target]').forEach(button=>{const chosen=(button.dataset.saveTarget||null)===savePresetTarget;button.classList.toggle('selected',chosen);button.setAttribute('aria-pressed',chosen);});
  $('presetName').value=target?target.name:saveNewPresetName;$('presetName').setCustomValidity('');
  $('saveModeNote').classList.toggle('overwriting',!!target);
  $('saveModeNote').innerHTML=target?`将覆盖用户预设<strong>「${esc(target.name)}」</strong>，保留该预设的位置。`:'将<strong>新建一个用户预设</strong>。保存后可在“我的”中找到。';
  $('confirmPresetSave').textContent=target?'覆盖保存':'新建保存';
}
function commitPresetSave(){
  const input=$('presetName'),name=input.value.trim();
  let problem=!name?'请输入预设名称':presets.some(p=>p.id!==savePresetTarget&&p.name===name)?'已有同名用户预设，请选择覆盖目标或使用其他名称':'';
  const index=savePresetTarget===null?-1:presets.findIndex(p=>p.id===savePresetTarget);
  if(savePresetTarget!==null&&index<0)problem='目标预设已不存在，请重新选择';
  if(problem){input.setCustomValidity(problem);input.reportValidity();return;}
  const record={id:savePresetTarget||crypto.randomUUID(),name,doc:{...copy(doc),name}};
  const next=index<0?[...presets,record]:presets.map((p,i)=>i===index?record:p);
  try{
    // Commit browser storage before replacing the in-memory list.
    localStorage.setItem(presetsKey,JSON.stringify(next));presets=next;
    renderPresets();closeModal();toast(index<0?'已新建用户预设，尚未应用到照片':`已覆盖用户预设「${name}」，尚未应用到照片`);
  }catch(error){toast('本地保存失败，预设尚未保存，请保留当前页面。');}
}

function reorder(direction){
  if(objectSelection.size!==1||[...objectSelection].some(objectProtected))return;const id=[...objectSelection][0],siblings=siblingsOf(id),at=siblings.indexOf(id),next=at+direction;
  if(next<0||next>=siblings.length)return;
  edit(()=>{const list=siblingsOf(id);[list[at],list[next]]=[list[next],list[at]];});
}
function duplicate(){if(!objectSelection.size)return;edit(()=>setObjectSelection(duplicateObjects(objectSelection),null,false));}
function remove(){if(!objectSelection.size)return;edit(()=>{removeObjects(objectSelection);setObjectSelection([],null,false);});}

function localPoint(e){return new DOMPoint(e.clientX,e.clientY).matrixTransform($('artboard').getScreenCTM().inverse());}
function bind(){
  $('undo').onclick=()=>history('undo');$('redo').onclick=()=>history('redo');$('deselect').onclick=()=>selectNode(null);
  $('addLayer').onclick=e=>addMenu(e.currentTarget);$('addComponent').onclick=e=>addMenu(e.currentTarget);
  $('savePreset').onclick=saveDialog;$('apply').onclick=applyDialog;$('presetPicker').onclick=choosePreset;
  $('layerUp').onclick=()=>reorder(1);$('layerDown').onclick=()=>reorder(-1);
  $('selectAll').onclick=()=>{selectedPhotos=new Set(photos.map((_,i)=>i));renderPhotos();renderHeader();persist();};$('clearSelection').onclick=()=>{selectedPhotos.clear();renderPhotos();renderHeader();persist();};
  $('resetMenu').onclick=e=>popover(e.currentTarget,[{label:'恢复本次编辑前',icon:'undo',action:'restore:entry'},{label:'恢复原始模板',icon:'restore',action:'restore:template'}]);
  $('help').onclick=()=>modal('编辑器使用提示',`<ul class="help-list"><li>从“添加组件”插入文字或拍摄信息。</li><li>点击画布组件或左侧图层，右侧显示属性。</li><li>拖动组件改变位置；单组件可拖右下角手柄缩放。</li><li>图层面板 Ctrl 多选、Shift 连选；画布空白处拖动框选，Ctrl 框选追加。</li><li>Ctrl+J 复制组件/组，Ctrl+D 取消当前区域选择；Ctrl+A 全选当前区域。</li><li>Ctrl+G 分组，Ctrl+Shift+G 取消分组；可展开组单独编辑。</li><li>方向键移动组件，Shift+方向键移动 10 px；缩略图区域左右键切图、Shift 扩展选择。</li><li>自动对齐参考其他组件与照片区域的边缘和中心，Alt 临时关闭吸附。</li><li>锁定组件后无法拖动，可在图层中解锁。</li><li><span class="kbd">Ctrl+Z</span> 撤销，<span class="kbd">Ctrl+Shift+Z</span> 重做。</li><li>横／竖／方用于适配检查，不裁改原照片。</li><li>先预览草稿，再明确应用范围。</li></ul><p class="hint">这是浏览器交互原型，使用演示照片；草稿与用户预设仅保存在此浏览器。本轮不导出图片。</p>`,`<button type="button" class="primary" data-close>知道了</button>`);
  $('closeModal').onclick=closeModal;
  $('modalForm').onsubmit=e=>{
    e.preventDefault();const action=e.submitter?.dataset.confirm;
    if(action==='apply'){
      const scope=$('modalBody').querySelector('[name=applyScope]:checked').value;
      const targets=scope==='current'?[current]:[...selectedPhotos];targets.forEach(i=>photos[i].applied=copy(doc));
      closeModal();persist();render();toast(`已将草稿应用到 ${targets.length} 张演示照片`);
    }else if(action==='save')commitPresetSave();
  };
  $('modal').addEventListener('input',e=>{if(e.target.id==='presetName')e.target.setCustomValidity('');});
  $('modal').onclick=e=>{if(e.target.closest('[data-close]')){closeModal();return;}const save=e.target.closest('[data-save-target]');if(save){selectPresetSaveTarget(save.dataset.saveTarget);return;}const a=e.target.closest('[data-load-template],[data-load-preset]');if(!a)return;edit(()=>{doc=a.dataset.loadTemplate?template(a.dataset.loadTemplate):copy(presets.find(p=>p.id===a.dataset.loadPreset).doc);selectedNode=null;});closeModal();toast('已载入编辑草稿，照片样式尚未改变');};
  $('layers').onclick=e=>{if(performance.now()<ignoreLayerClickUntil)return;const layer=e.target.closest('[data-layer]');if(!layer)return;const id=layer.dataset.layer,action=e.target.closest('[data-layer-action]');if(action){edit(()=>{const n=doc.nodes.find(n=>n.id===id);n[action.dataset.layerAction]=!n[action.dataset.layerAction];});}else selectNode(id);};
  $('layers').onkeydown=e=>{if(e.target.matches('[data-layer]')&&['Enter',' '].includes(e.key)){e.preventDefault();selectNode(e.target.dataset.layer);}};
  $('properties').addEventListener('input',e=>{
    const el=e.target;if(!el.matches('[data-prop],[data-border],[data-canvas-color],[data-canvas-hex]'))return;
    if(el.value==='')return;if(!pending)pending=copy(doc);
    if(el.dataset.border){const value=clamp(el.value,0,40);setBorderSize(el.dataset.border,value);if(doc.linked)$('properties').querySelectorAll('[data-border]').forEach(input=>input.value=value);}
    else if(el.hasAttribute('data-canvas-color')||el.hasAttribute('data-canvas-hex')){if(/^#[\da-f]{6}$/i.test(el.value)){doc.background=el.value;$('properties').querySelector('[data-canvas-color]').value=doc.background;$('properties').querySelector('[data-canvas-hex]').value=doc.background.toUpperCase();}}
    else if(node()&&!node().locked){const key=el.dataset.prop;if(['x','y','opacity','spacing','fontSize'].includes(key))node()[key]=clamp(el.value,key==='fontSize'?8:0,key==='spacing'?15:key==='fontSize'?110:100);else if(key==='color'||key==='colorHex'){if(/^#[\da-f]{6}$/i.test(el.value)){node().color=el.value;$('properties').querySelector('[data-prop=color]').value=node().color;$('properties').querySelector('[data-prop=colorHex]').value=node().color.toUpperCase();}}else if(key==='anchor'){changeNodeAnchor(node(),el.value);el.value=node().anchor;for(const axis of ['x','y'])$('properties').querySelector(`[data-prop=${axis}]`).value=Math.round(node()[axis]*10)/10;}else if(['name','text','font'].includes(key))node()[key]=el.value;
      if(key==='opacity')$('opacityValue').textContent=Math.round(node().opacity)+'%';}
    renderCanvas();renderLayers();updated();
  });
  $('properties').addEventListener('change',()=>{finishEdit();renderHeader();});
  $('properties').addEventListener('focusout',()=>finishEdit());
  $('properties').onclick=e=>{const el=e.target.closest('[data-align],[data-swatch],#duplicateNode,#deleteNode,#propertiesAdd,#linked');if(!el)return;if(el.id==='propertiesAdd'){addMenu(el);return;}if(el.id==='duplicateNode'){duplicate();return;}if(el.id==='deleteNode'){remove();return;}edit(()=>{if(el.dataset.align&&node()&&!node().locked)node().align=el.dataset.align;if(el.dataset.swatch)doc.background=el.dataset.swatch;if(el.id==='linked'){doc.linked=el.checked;}});};
  $('thumbnails').onclick=e=>{const el=e.target.closest('[data-photo]');if(!el)return;finishEdit();const i=+el.dataset.photo;if(e.shiftKey){const range=Array.from({length:Math.abs(i-photoAnchor)+1},(_,n)=>Math.min(i,photoAnchor)+n);selectedPhotos=new Set(e.ctrlKey||e.metaKey?[...selectedPhotos,...range]:range);current=i;}else if(e.ctrlKey||e.metaKey){if(selectedPhotos.has(i)){selectedPhotos.delete(i);current=selectedPhotos.size?[...selectedPhotos].at(-1):i;}else{selectedPhotos.add(i);current=i;}photoAnchor=i;}else{selectedPhotos=new Set([i]);current=photoAnchor=i;}render();persist();};
  let wheelTarget=null,scrollFrame=0;
  $('thumbnails').addEventListener('wheel',e=>{const list=$('thumbnails');const delta=e.deltaX||e.deltaY;if(list.scrollWidth<=list.clientWidth)return;e.preventDefault();const reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;if(reduce){list.scrollLeft+=delta;return;}wheelTarget=clamp((wheelTarget??list.scrollLeft)+delta,0,list.scrollWidth-list.clientWidth);if(scrollFrame)return;const tick=()=>{const diff=wheelTarget-list.scrollLeft;list.scrollLeft+=diff*.25;if(Math.abs(diff)>1)scrollFrame=requestAnimationFrame(tick);else{list.scrollLeft=wheelTarget;scrollFrame=0;wheelTarget=null;}};scrollFrame=requestAnimationFrame(tick);},{passive:false});
  $('thumbnails').onpointerdown=()=>{cancelAnimationFrame(scrollFrame);scrollFrame=0;wheelTarget=null;};
  document.querySelectorAll('[data-preview]').forEach(el=>el.onclick=()=>{preview=el.dataset.preview;renderCanvas();renderHeader();});
  document.querySelectorAll('[data-left]').forEach(el=>el.onclick=()=>{leftTab=el.dataset.left;document.querySelectorAll('[data-left]').forEach(b=>b.classList.toggle('active',b===el));$('layersPane').hidden=leftTab!=='layers';$('directoriesPane').hidden=leftTab!=='directories';});
  document.querySelectorAll('[data-layout]').forEach(el=>el.onclick=()=>{settings.layout=el.dataset.layout;applyLayout();persist();});
  document.addEventListener('click',e=>{const action=e.target.closest('[data-menu-action]');if(action){const [type,value]=action.dataset.menuAction.split(':');if(type==='add')add(value);if(type==='restore')edit(()=>{doc=value==='entry'?copy(entryDoc):template(doc.template);selectedNode=null;});$('popover').hidden=true;}else if(!e.target.closest('#popover,#addComponent,#addLayer,#propertiesAdd,#resetMenu'))$('popover').hidden=true;});
  // Component selection, marquee and drag are bound by bindObjectEditor().
  document.querySelectorAll('[data-resize]').forEach(el=>{let start=null;el.onpointerdown=e=>{if(e.button!==0)return;start={x:e.clientX,y:e.clientY,value:settings[el.dataset.resize]};el.setPointerCapture(e.pointerId);$('workspace').classList.add('resizing');el.classList.add('dragging');e.preventDefault();};el.onpointermove=e=>{if(!start)return;const key=el.dataset.resize;settings[key]=clamp(start.value+(key==='left'?e.clientX-start.x:key==='right'?start.x-e.clientX:start.y-e.clientY),key==='bottom'?125:key==='left'?180:280,key==='bottom'?260:key==='left'?Math.max(180,Math.min(300,$('workspace').clientWidth-settings.right-440)):Math.max(280,Math.min(400,$('workspace').clientWidth-settings.left-440)));applyLayout();};const end=()=>{if(!start)return;start=null;$('workspace').classList.remove('resizing');el.classList.remove('dragging');persist();};el.onpointerup=end;el.onpointercancel=end;});
  document.addEventListener('keydown',e=>{if(e.defaultPrevented||e.target.matches('input,textarea,select')||$('modal').open)return;const control=e.ctrlKey||e.metaKey;if(control&&e.key.toLowerCase()==='z'){e.preventDefault();history(e.shiftKey?'redo':'undo');}else if(control&&e.key.toLowerCase()==='j'&&editorSelectionContext==='objects'){e.preventDefault();duplicate();}else if(['Delete','Backspace'].includes(e.key)&&editorSelectionContext==='objects'){e.preventDefault();remove();}else if(e.key==='Escape'){$('popover').hidden=true;}else if(node()&&!node().locked&&['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key)){e.preventDefault();edit(()=>{const step=e.shiftKey?2:.2;if(e.key==='ArrowLeft')node().x=clamp(node().x-step,0,100);if(e.key==='ArrowRight')node().x=clamp(node().x+step,0,100);if(e.key==='ArrowUp')node().y=clamp(node().y-step,0,100);if(e.key==='ArrowDown')node().y=clamp(node().y+step,0,100);});}});
  window.addEventListener('resize',()=>{finishInlineText();applyLayout();renderCanvas();});
  window.addEventListener('pagehide',()=>{finishInlineText();clearTimeout(saveTimer);try{localStorage.setItem(draftKey,JSON.stringify({version:1,doc,current,selectedPhotos:[...selectedPhotos],settings,applied:photos.map(p=>p.applied)}));}catch(e){/* UI already reports storage failures during editing. */}});
}
function renderInspectorTabs() {
  document.querySelectorAll('[data-inspector]').forEach(button=>{
    const active=button.dataset.inspector===rightPanel;
    button.classList.toggle('active',active);button.setAttribute('aria-selected',active);
    button.tabIndex=active?0:-1;
  });
  $('presetsPane').hidden=rightPanel!=='presets';
  $('properties').hidden=rightPanel==='presets';
  $('properties').setAttribute('aria-labelledby',rightPanel==='canvas'?'tabCanvas':'tabComponent');
}
function switchInspector(panel) {
  finishInlineText();finishEdit();rightPanel=panel;renderProperties();
}
function presetPreview(document) {
  const ratio=photos[current].ratio,pw=ratio>=1?1000*ratio:1000,ph=ratio>=1?1000:1000/ratio;
  const b=Object.fromEntries(Object.entries(document.borders).map(([k,v])=>[k,v*10]));
  const g={pw,ph,b,w:pw+b.left+b.right,h:ph+b.top+b.bottom};
  let body=`<rect width="${g.w}" height="${g.h}" fill="${document.background}"/><svg x="${b.left}" y="${b.top}" width="${pw}" height="${ph}" viewBox="18 150 487 314" preserveAspectRatio="xMidYMid slice" overflow="hidden"><image href="../reference.png" width="1536" height="1024"/></svg>`;
  for(const n of document.nodes){
    if(!objectVisible(n.id,document)||!content(n)||(n.anchor==='bottom'&&!b.bottom))continue;
    const p=nodePoint(n,g);
    body+=`<text x="${p.x}" y="${p.y}" text-anchor="${n.align==='left'?'start':n.align==='right'?'end':'middle'}" dominant-baseline="central" font-family='${esc(fonts[n.font])}' font-size="${n.fontSize}" letter-spacing="${n.spacing}" font-style="${n.font==='signature'?'italic':'normal'}" fill="${n.color}" opacity="${n.opacity/100}">${content(n).split(/\r?\n/).map((line,i,lines)=>`<tspan x="${p.x}" dy="${i===0?-(lines.length-1)*n.fontSize*.7:n.fontSize*1.4}">${esc(line)||' '}</tspan>`).join('')}</text>`;
  }
  return `<svg viewBox="0 0 ${g.w} ${g.h}" role="img" aria-label="${esc(document.name)}样式预览">${body}</svg>`;
}
function renderPresets() {
  const items=[...['gallery','film'].map(key=>({key,type:'builtin',name:template(key).name,doc:template(key)})),...presets.map(p=>({key:p.id,type:'user',name:p.name,doc:p.doc}))];
  const shown=items.filter(p=>(presetFilter==='all'||p.type===presetFilter)&&p.name.toLocaleLowerCase().includes(presetQuery.trim().toLocaleLowerCase()));
  $('presetCount').textContent=`${shown.length} 款`;
  $('presetCards').innerHTML=shown.map(p=>`<button class="preset-card ${snapshotEqual(p.doc,doc)?'active':''}" ${p.type==='builtin'?`data-load-template="${p.key}"`:`data-load-preset="${esc(p.key)}"`} aria-label="载入预设 ${esc(p.name)}" aria-pressed="${snapshotEqual(p.doc,doc)}"><span class="preset-preview">${presetPreview(p.doc)}</span><b>${esc(p.name)}</b><small>${p.type==='builtin'?'内置模板':'用户预设'}</small></button>`).join('')||`<div class="preset-empty">${presetQuery?'没有找到匹配的预设':presetFilter==='user'?'还没有用户预设，编辑完成后可在下方另存。':'暂无预设'}</div>`;
  $('presetCards').insertAdjacentHTML('beforeend',`<button class="new-blank" data-load-template="blank">${icon('plus')}从空白画布开始</button>`);
  document.querySelectorAll('[data-preset-filter]').forEach(button=>button.classList.toggle('active',button.dataset.presetFilter===presetFilter));
}
function finishInlineText(cancel=false) {
  if(!inlineEdit)return;
  const active=inlineEdit;inlineEdit=null;
  const target=doc.nodes.find(n=>n.id===active.id);
  if(!cancel&&target){target.text=$('inlineTextEditor').value;checkpoint(active.before);}
  $('inlineTextBox').hidden=true;
  renderHeader();renderCanvas();
  const field=$('properties').querySelector('[data-prop=text]');
  if(field&&target)field.value=target.text;
}
function startInlineText(id) {
  finishInlineText();
  const target=doc.nodes.find(n=>n.id===id);
  if(!target)return;
  // Double-click always drills into a group, even for read-only EXIF content.
  selectNode(id);
  if(objectLocked(target.id)||!['text','author'].includes(target.type))return;
  const element=[...$('artboard').querySelectorAll('[data-node]')].find(el=>el.dataset.node===id);
  if(!element)return;
  const rect=element.getBoundingClientRect(),zone=$('canvasZone').getBoundingClientRect();
  const scale=$('artboard').getScreenCTM().a;
  inlineEdit={id,before:copy(doc)};
  const box=$('inlineTextBox'),input=$('inlineTextEditor');
  const width=Math.min(Math.max(rect.width+24,200),zone.width-20);
  box.style.left=clamp(rect.left-zone.left-8,8,zone.width-width-8)+'px';
  box.style.top=clamp(rect.top-zone.top-7,35,zone.height-105)+'px';
  box.style.width=width+'px';box.hidden=false;
  input.value=target.text;
  input.style.fontFamily=fonts[target.font];input.style.fontSize=Math.max(14,target.fontSize*scale)+'px';
  input.style.fontStyle=target.font==='signature'?'italic':'normal';
  input.style.letterSpacing=target.spacing*scale+'px';input.style.textAlign=target.align;
  input.style.color=target.color;input.style.background=doc.background;
  input.style.height='auto';input.style.height=Math.min(230,Math.max(38,input.scrollHeight+2))+'px';
  renderCanvas();input.focus();input.select();
}
function bindEditorRefinements() {
  document.querySelectorAll('[data-inspector]').forEach(button=>{
    button.onclick=()=>switchInspector(button.dataset.inspector);
    button.onkeydown=e=>{
      if(!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;
      e.preventDefault();e.stopPropagation();const tabs=[...document.querySelectorAll('[data-inspector]')],i=tabs.indexOf(button);
      const next=e.key==='Home'?0:e.key==='End'?2:(i+(e.key==='ArrowLeft'?2:1))%3;
      tabs[next].focus();switchInspector(tabs[next].dataset.inspector);
    };
  });
  $('presetSearch').oninput=e=>{presetQuery=e.target.value;renderPresets();};
  document.querySelectorAll('[data-preset-filter]').forEach(button=>button.onclick=()=>{presetFilter=button.dataset.presetFilter;renderPresets();});
  $('presetsPane').onclick=e=>{
    const card=e.target.closest('[data-load-template],[data-load-preset]');if(!card)return;
    edit(()=>{doc=card.dataset.loadTemplate?template(card.dataset.loadTemplate):copy(presets.find(p=>p.id===card.dataset.loadPreset).doc);selectedNode=null;rightPanel=card.dataset.loadTemplate==='blank'?'canvas':'presets';});
    toast('已载入草稿，可继续编辑；照片样式尚未改变');
  };
  $('artboard').ondblclick=e=>{e.preventDefault();if(inlineEdit||canvasSpaceHeld)return;drag=null;guide=false;startInlineText(e.target.closest('[data-node]')?.dataset.node||lastCanvasHit);};
  $('inlineTextEditor').onkeydown=e=>{
    if(e.isComposing)return;
    if(e.key==='Escape'){e.preventDefault();e.stopPropagation();finishInlineText(true);}
    else if(e.key==='Enter'&&(e.ctrlKey||e.metaKey)){e.preventDefault();finishInlineText();}
  };
  $('inlineTextEditor').oninput=e=>{e.target.style.height='auto';e.target.style.height=Math.min(230,Math.max(38,e.target.scrollHeight+2))+'px';};
  $('inlineTextEditor').onblur=()=>finishInlineText();
  document.addEventListener('pointerdown',e=>{if(inlineEdit&&!e.target.closest('#inlineTextBox'))finishInlineText();},true);


}
// View navigation stays outside the document and its undo/save history.
let canvasSpaceHeld=false,canvasPan=null;
const canvasView={zoom:1,x:0,y:0};
function updateCanvasView(){
  $('artboard').style.transform=`translate(${canvasView.x}px,${canvasView.y}px) scale(${canvasView.zoom})`;
  $('canvasZoom').textContent=`${Math.round(canvasView.zoom*100)}%`;
  $('canvasZone').classList.toggle('canvas-hand',canvasSpaceHeld);
  $('canvasZone').classList.toggle('canvas-panning',!!canvasPan);
}
function resetCanvasView(){
  finishInlineText();Object.assign(canvasView,{zoom:1,x:0,y:0});updateCanvasView();renderCanvas();
}
function bindCanvasNavigation(){
  const zone=$('canvasZone'),svg=$('artboard');
  const typing=e=>e.target.closest('input,textarea,select,[contenteditable=true]');
  function endPan(cancel=false){
    if(!canvasPan)return;
    const pan=canvasPan;canvasPan=null;
    if(cancel){canvasView.x=pan.x;canvasView.y=pan.y;}
    if(zone.hasPointerCapture(pan.id))zone.releasePointerCapture(pan.id);
    updateCanvasView();
  }
  document.addEventListener('keydown',e=>{
    if(e.code==='Space'&&!typing(e)&&!$('modal').open&&!objectOperation){
      e.preventDefault();e.stopImmediatePropagation();canvasSpaceHeld=true;updateCanvasView();
    }else if(e.key==='Escape'&&canvasPan){
      e.preventDefault();e.stopImmediatePropagation();endPan(true);
    }
  },true);
  document.addEventListener('keyup',e=>{
    if(e.code==='Space'){canvasSpaceHeld=false;updateCanvasView();}
  },true);
  window.addEventListener('blur',()=>{canvasSpaceHeld=false;endPan();updateCanvasView();});
  zone.addEventListener('wheel',e=>{
    if(!e.altKey)return;
    e.preventDefault();
    if(objectOperation||canvasPan||$('modal').open)return;
    finishInlineText();
    const delta=e.deltaY*(e.deltaMode===1?16:e.deltaMode===2?zone.clientHeight:1);
    const zoom=clamp(canvasView.zoom*Math.exp(-delta*.0015),.1,8);
    const ratio=zoom/canvasView.zoom,rect=svg.getBoundingClientRect();
    // Preserve the screen position of the point beneath the pointer.
    canvasView.x+=(e.clientX-(rect.left+rect.width/2))*(1-ratio);
    canvasView.y+=(e.clientY-(rect.top+rect.height/2))*(1-ratio);
    canvasView.zoom=zoom;updateCanvasView();renderCanvas();
  },{passive:false});
  zone.addEventListener('pointerdown',e=>{
    if(!canvasSpaceHeld||e.button!==0||e.target.closest('#inlineTextBox'))return;
    e.preventDefault();e.stopImmediatePropagation();finishInlineText();finishEdit();
    lastCanvasClick=null;lastCanvasHit=null;
    canvasPan={id:e.pointerId,clientX:e.clientX,clientY:e.clientY,x:canvasView.x,y:canvasView.y};
    zone.focus({preventScroll:true});zone.setPointerCapture(e.pointerId);updateCanvasView();
  },true);
  zone.addEventListener('pointermove',e=>{
    if(!canvasPan||e.pointerId!==canvasPan.id)return;
    e.preventDefault();e.stopImmediatePropagation();
    canvasView.x=canvasPan.x+e.clientX-canvasPan.clientX;
    canvasView.y=canvasPan.y+e.clientY-canvasPan.clientY;updateCanvasView();
  },true);
  zone.addEventListener('pointerup',e=>{if(canvasPan&&e.pointerId===canvasPan.id){e.stopImmediatePropagation();endPan();}},true);
  zone.addEventListener('pointercancel',e=>{if(canvasPan&&e.pointerId===canvasPan.id){e.stopImmediatePropagation();endPan(true);}},true);
  zone.addEventListener('lostpointercapture',()=>endPan());
  $('fitCanvas').onclick=resetCanvasView;updateCanvasView();
}
load();fillIcons();bind();bindEditorRefinements();bindObjectEditor();bindCanvasNavigation();applyLayout();render();if(storageError)$('storageStatus').textContent='部分本地记录读取失败';
