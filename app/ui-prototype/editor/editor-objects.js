'use strict';
// Object hierarchy is separate from text data: grouping never flattens content.
let objectSelection=new Set(),layerRangeAnchor=null,collapsedGroups=new Set();
let objectOperation=null,objectGuides=[],objectMarquee=null;
let editorSelectionContext='objects';

// Shared 24 px grid: rounded neutral outlines and small warm-gold details.
function layerIcon(name){
  const gold=path=>`<path class="layer-icon-accent" d="${path}"/>`;
  const shapes={
    text:'<path d="M5 7V5.5A1.5 1.5 0 0 1 6.5 4h11A1.5 1.5 0 0 1 19 5.5V7M12 4v14M9 18h6"/>'+gold('M7 21h10'),
    params:'<path d="M5 5h14M5 12h14M5 19h14"/>'+gold('M8 3v4m8 3v4m-6 3v4'),
    author:'<path d="m6 15 9.5-10a2 2 0 0 1 3 3L9 18l-4 1 1-4ZM14 6l4 4"/>'+gold('M4 22c4-4 7 1 11-2h5'),
    camera:'<path d="M4.5 7.5h3L9 5h6l1.5 2.5h3a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-15a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2ZM16 13.5a4 4 0 1 1-8 0 4 4 0 0 1 8 0"/>'+gold('M18 10h.1'),
    lens:'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/>'+gold('M9 14.5a4 4 0 0 0 5.5-5.5'),
    time:'<circle cx="12" cy="12" r="9"/>'+gold('M12 6v6l4 2'),
    location:'<path d="M18.5 10c0 5-6.5 11-6.5 11S5.5 15 5.5 10a6.5 6.5 0 1 1 13 0Z"/>'+gold('M14.5 10a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0'),
    eye:'<path d="M2.5 12S6 6.5 12 6.5s9.5 5.5 9.5 5.5-3.5 5.5-9.5 5.5S2.5 12 2.5 12Z"/>'+gold('M14.5 12a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0'),
    eyeOff:'<path d="M8 7.3a10 10 0 0 1 4-.8c6 0 9.5 5.5 9.5 5.5a18 18 0 0 1-3 3.4M5.5 8.5a18 18 0 0 0-3 3.5s3.5 5.5 9.5 5.5a10 10 0 0 0 4-.8"/>'+gold('m4 4 16 16'),
    lock:'<rect x="5" y="10" width="14" height="11" rx="2.5"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>'+gold('M12 14.5v2.5'),
    unlock:'<rect x="5" y="10" width="14" height="11" rx="2.5"/><path d="M8 10V7a4 4 0 0 1 7.5-2"/>'+gold('M12 14.5v2.5'),
    group:'<path d="M3 8V6a2 2 0 0 1 2-2h5l2.5 3H19a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8ZM3 9h18"/>'+gold('M7 16h5'),
    groupOpen:'<path d="M3 11V6a2 2 0 0 1 2-2h5l2 3h7a2 2 0 0 1 2 2v2M5 20h13a2 2 0 0 0 2-1.5l2-6.5H5L3 18a1.5 1.5 0 0 0 2 2Z"/>'+gold('M8 16h5'),
    groupAction:'<rect x="3" y="3" width="18" height="18" rx="4"/><path d="M7 8h4v4H7Z"/>'+gold('M13 12h4v5h-4Z'),
    ungroup:'<path d="M9 3H6a3 3 0 0 0-3 3v3M15 3h3a3 3 0 0 1 3 3v3M3 15v3a3 3 0 0 0 3 3h3M21 15v3a3 3 0 0 1-3 3h-3M7 7h4v4H7Z"/>'+gold('M14 14h4v4h-4Z'),
    add:'<rect x="3" y="3" width="18" height="18" rx="5"/>'+gold('M12 8v8M8 12h8'),
    arrowUp:'<path d="M6 20h12M12 16V4"/>'+gold('m7.5 8.5 4.5-4.5 4.5 4.5'),
    arrowDown:'<path d="M6 4h12M12 8v12"/>'+gold('m7.5 15.5 4.5 4.5 4.5-4.5'),
    chevronDown:'<path d="m7 9.5 5 5 5-5"/>',arrowRight:'<path d="m9.5 7 5 5-5 5"/>',
    grip:[7,12,17].flatMap(y=>[9,15].map(x=>`<circle cx="${x}" cy="${y}" r=".8" fill="currentColor" stroke="none"/>`)).join(''),
    savePreset:'<path d="M6 4h10.2a2 2 0 0 1 1.4.6l1.8 1.8a2 2 0 0 1 .6 1.4V18a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z"/><path d="M8 4v5a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4M8 20v-5a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v5"/>',
    applyStyle:'<path d="M5 12h14m-5-5 5 5-5 5"/>',
    dropInside:'<rect x="3" y="3" width="18" height="18" rx="4"/>'+gold('M8 9h8v6H8Z'),
    dropOutside:'<path d="M13 20H7a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3h10a3 3 0 0 1 3 3v6"/>'+gold('M15 15h7v7h-7Z')
  };
  return `<svg class="layer-ui-icon" viewBox="0 0 24 24" aria-hidden="true">${shapes[name]||shapes.text}</svg>`;
}
function photoAlignmentReference(g){return{x:g.b.left,y:g.b.top,width:g.pw,height:g.ph,kind:'photo',label:'照片'};}

// Resolve an insertion at the end of a group using horizontal indentation.
// Paint-order arrays run bottom-to-top; UI entries run top-to-bottom.
function resolveLayerDrop(entries,hitId,fraction,pointerX,rowLeft){
  const hit=entries.find(r=>r.id===hitId);if(!hit)return null;
  const index=entries.indexOf(hit),lastDescendant=id=>{
    const start=entries.findIndex(r=>r.id===id);let last=entries[start];
    for(let i=start+1;i<entries.length&&entries[i].depth>entries[start].depth;i++)last=entries[i];
    return last;
  };
  const result=(target,placement,indicator,lineAt,depth)=>{
    const inside=placement.startsWith('inside')||parentId(target)!==null;
    return{target,placement,indicator,lineAt,depth,inside,status:inside?'组内':'组外',indent:7+Math.min(depth,4)*12+(inside?24:0)};
  };
  const threshold=depth=>rowLeft+38+(depth+1)*12;
  if(hit.item.children&&fraction>.28&&fraction<.72)
    return result(hitId,'inside',hitId,'inside',hit.depth+1);
  if(fraction>=.5){
    // At the bottom boundary of any ancestor, allow an outdent to its sibling.
    const trailing=ancestors(hitId).reverse().filter(id=>lastDescendant(id)?.id===hitId);
    if(hit.item.children)trailing.push(hitId);
    for(const id of trailing){const group=entries.find(r=>r.id===id);if(pointerX<threshold(group.depth))return result(id,'after',lastDescendant(id).id,'after',group.depth);}
    if(hit.item.children)return result(hitId,'inside-bottom',lastDescendant(hitId).id,'after',hit.depth+1);
  }else{
    const leading=ancestors(hitId).reverse().filter(id=>entries.findIndex(r=>r.id===id)+1===index);
    for(const id of leading){const group=entries.find(r=>r.id===id);if(pointerX<threshold(group.depth))return result(id,'before',id,'before',group.depth);}
  }
  return result(hitId,fraction<.5?'before':'after',hitId,fraction<.5?'before':'after',hit.depth);
}

function ensureObjectTree(value) {
  const ids=new Set(value.nodes.map(n=>n.id)),groups=[];
  for(const raw of Array.isArray(value.groups)?value.groups:[]){
    if(!raw||typeof raw.id!=='string'||ids.has(raw.id)||groups.length>=80)continue;
    ids.add(raw.id);groups.push({id:raw.id,name:String(raw.name||'组件组').slice(0,80),visible:raw.visible!==false,locked:!!raw.locked,children:Array.isArray(raw.children)?[...raw.children]:[]});
  }
  const entries=new Map([...value.nodes,...groups].map(n=>[n.id,n]));
  const mentioned=new Set(groups.flatMap(g=>g.children));
  const roots=Array.isArray(value.order)?value.order:[...value.nodes,...groups].filter(n=>!mentioned.has(n.id)).map(n=>n.id);
  const visited=new Set();
  function walk(order,path=new Set()){
    const result=[];
    for(const id of order){
      if(!entries.has(id)||visited.has(id)||path.has(id))continue;
      visited.add(id);const item=entries.get(id);
      if(item.children)item.children=walk(item.children,new Set([...path,id]));
      result.push(id);
    }
    return result;
  }
  value.order=walk(roots);
  for(const item of [...groups,...value.nodes])if(!visited.has(item.id))value.order.push(...walk([item.id]));
  value.groups=groups;
  const leaves=[];
  function flatten(order){for(const id of order){const item=entries.get(id);if(item.children)flatten(item.children);else leaves.push(item);}}
  flatten(value.order);value.nodes=leaves;return value;
}
function entity(id,document=doc){return document.nodes.find(n=>n.id===id)||(document.groups||[]).find(g=>g.id===id);}
function parentId(id){return (doc.groups||[]).find(g=>g.children.includes(id))?.id||null;}
function ancestors(id){const result=[];let p=parentId(id);while(p&&!result.includes(p)){result.push(p);p=parentId(p);}return result;}
function rootObject(id){return ancestors(id).at(-1)||id;}
function siblingsOf(id){const parent=parentId(id);return parent?entity(parent).children:doc.order;}
function leafIds(id){const item=entity(id);return !item?[]:item.children?item.children.flatMap(leafIds):[id];}
function objectVisible(id,document=doc){
  const item=entity(id,document);if(!item||item.visible===false)return false;
  const seen=new Set([id]);let parent=(document.groups||[]).find(g=>g.children.includes(id));
  while(parent&&!seen.has(parent.id)){if(parent.visible===false)return false;seen.add(parent.id);parent=(document.groups||[]).find(g=>g.children.includes(parent.id));}
  return true;
}
function objectLocked(id){return !!entity(id)?.locked||ancestors(id).some(p=>entity(p).locked);}
function objectProtected(id){return objectLocked(id)||leafIds(id).some(objectLocked);}
function treeIds(){const result=[];function visit(order){for(const id of order){result.push(id);const item=entity(id);if(item?.children)visit(item.children);}}visit(doc.order||[]);return result;}
function topObjectIds(ids){
  const set=new Set([...ids].filter(id=>entity(id)));
  return treeIds().filter(id=>set.has(id)&&!ancestors(id).some(p=>set.has(p)));
}
function chosenLeaves(){return [...new Set(topObjectIds(objectSelection).flatMap(leafIds))];}
function syncObjectSelection(){
  ensureObjectTree(doc);
  if(selectedNode===null)objectSelection.clear();
  else if(entity(selectedNode)&&!objectSelection.has(selectedNode))objectSelection=new Set([selectedNode]);
  objectSelection=new Set(topObjectIds(objectSelection));
  if(!objectSelection.has(selectedNode))selectedNode=[...objectSelection].at(-1)||null;
}
function setObjectSelection(ids,primary=null,refresh=true){
  ensureObjectTree(doc);objectSelection=new Set(topObjectIds(ids));
  selectedNode=objectSelection.has(primary)?primary:[...objectSelection].at(-1)||null;
  rightPanel=selectedNode?'component':'canvas';
  if(refresh){renderHeader();renderLayers();renderProperties();renderCanvas();}
}
function visibleLayerEntries(){
  const result=[];function visit(order,depth){for(const id of [...order].reverse()){const item=entity(id);if(!item)continue;result.push({id,depth,item});if(item.children&&!collapsedGroups.has(id))visit(item.children,depth+1);}}
  visit(doc.order||[],0);return result;
}
function selectLayerObject(id,event={}){
  finishEdit();let ids;
  if(event.shiftKey){const rows=visibleLayerEntries().map(r=>r.id),start=rows.indexOf(layerRangeAnchor),end=rows.indexOf(id);const range=rows.slice(Math.min(start<0?end:start,end),Math.max(start<0?end:start,end)+1);ids=event.ctrlKey||event.metaKey?[...objectSelection,...range]:range;}
  else if(event.ctrlKey||event.metaKey){ids=new Set(objectSelection);ids.has(id)?ids.delete(id):ids.add(id);layerRangeAnchor=id;}
  else{ids=[id];layerRangeAnchor=id;}
  setObjectSelection(ids,id);
}
function detachObject(id){const siblings=siblingsOf(id),index=siblings.indexOf(id);if(index>=0)siblings.splice(index,1);}
function groupObjects(ids){
  ensureObjectTree(doc);const chosen=topObjectIds(ids);if(chosen.length<2)return null;
  const paths=chosen.map(id=>ancestors(id).reverse());let common=null;
  for(let i=0;i<Math.min(...paths.map(p=>p.length));i++){if(paths.every(p=>p[i]===paths[0][i]))common=paths[0][i];else break;}
  const siblings=common?entity(common).children:doc.order;
  const branches=chosen.map(id=>{let branch=id;while(parentId(branch)!==common&&parentId(branch))branch=parentId(branch);return branch;});
  const prefix=siblings.slice(0,Math.max(...branches.map(id=>siblings.indexOf(id)))+1);
  chosen.forEach(detachObject);const at=prefix.filter(id=>siblings.includes(id)).length;
  const id=crypto.randomUUID();doc.groups.push({id,name:'组件组 '+(doc.groups.length+1),visible:true,locked:false,children:chosen});siblings.splice(at,0,id);
  ensureObjectTree(doc);return id;
}
function ungroupObjects(ids){
  ensureObjectTree(doc);const selected=topObjectIds(ids),result=[];
  for(const id of selected){const group=entity(id);if(!group?.children){result.push(id);continue;}const siblings=siblingsOf(id),at=siblings.indexOf(id);siblings.splice(at,1,...group.children);result.push(...group.children);doc.groups=doc.groups.filter(g=>g.id!==id);collapsedGroups.delete(id);}
  ensureObjectTree(doc);return result;
}
function duplicateObjects(ids){
  ensureObjectTree(doc);const chosen=topObjectIds(ids),result=[];
  function clone(id){const original=entity(id),n=copy(original);n.id=crypto.randomUUID();n.name+=' · 副本';if(n.children){n.children=original.children.map(clone);doc.groups.push(n);}else doc.nodes.push(n);return n.id;}
  for(const id of chosen){const siblings=siblingsOf(id),at=siblings.indexOf(id),newId=clone(id);siblings.splice(at+1,0,newId);result.push(newId);}
  ensureObjectTree(doc);return result;
}
function removeObjects(ids){
  const chosen=topObjectIds(ids).filter(id=>!objectProtected(id)),removed=new Set();
  function collect(id){removed.add(id);for(const child of entity(id)?.children||[])collect(child);}
  chosen.forEach(id=>{collect(id);detachObject(id);});
  doc.nodes=doc.nodes.filter(n=>!removed.has(n.id));doc.groups=doc.groups.filter(g=>!removed.has(g.id));ensureObjectTree(doc);return [...removed];
}
function reorderObjects(ids,targetId,placement){
  ensureObjectTree(doc);const chosen=topObjectIds(ids);
  if(!chosen.length||chosen.some(objectProtected)||!entity(targetId)||chosen.includes(targetId)||ancestors(targetId).some(id=>chosen.includes(id)))return false;
  const intoGroup=placement.startsWith('inside');
  const target=entity(targetId);if(intoGroup&&(!target.children||objectLocked(targetId)))return false;
  if(!intoGroup&&parentId(targetId)&&objectLocked(parentId(targetId)))return false;
  chosen.forEach(detachObject);
  const destination=intoGroup?target.children:siblingsOf(targetId);
  const at=intoGroup?(placement==='inside-bottom'?0:destination.length):destination.indexOf(targetId)+(placement==='before'?1:0);
  // Arrays are in paint order; "before" is visually above in the layer list.
  destination.splice(at,0,...chosen);if(intoGroup)collapsedGroups.delete(targetId);
  ensureObjectTree(doc);return true;
}
function groupObjectSelection(){
  if(objectSelection.size<2)return;
  if([...objectSelection].some(objectProtected)){toast('选区包含锁定组件，请先解锁再分组');return;}
  edit(()=>{const id=groupObjects(objectSelection);setObjectSelection([id],id,false);});toast('已分组，可展开编辑内部组件');
}
function ungroupObjectSelection(){
  const groups=[...objectSelection].filter(id=>entity(id)?.children&&!objectProtected(id));if(!groups.length)return;
  const kept=[...objectSelection].filter(id=>!groups.includes(id));
  edit(()=>setObjectSelection([...kept,...ungroupObjects(groups)],null,false));toast('已取消分组，组件内容与位置保留');
}
function unionObjectBounds(bounds){
  const items=bounds.filter(Boolean);if(!items.length)return null;
  const x=Math.min(...items.map(b=>b.x)),y=Math.min(...items.map(b=>b.y));
  return{x,y,width:Math.max(...items.map(b=>b.x+b.width))-x,height:Math.max(...items.map(b=>b.y+b.height))-y};
}
function leafBounds(id){const el=[...$('artboard').querySelectorAll('[data-node]')].find(el=>el.dataset.node===id);if(!el)return null;const b=el.getBBox();return{x:b.x,y:b.y,width:b.width,height:b.height};}
function objectBounds(id){return unionObjectBounds(leafIds(id).map(leafBounds));}
function selectedBounds(){return unionObjectBounds([...objectSelection].map(objectBounds));}
function appendSvg(markup){const group=document.createElementNS('http://www.w3.org/2000/svg','g');group.innerHTML=markup;$('artboard').append(group);return group;}
function drawObjectSelection(){
  const g=geometry(),scale=$('artboard').getScreenCTM()?.a||1,pad=5/scale,bounds=selectedBounds();
  if(bounds&&!inlineEdit){
    let html='';for(const id of objectSelection){const b=objectBounds(id);if(b)html+=`<rect class="selection-box ${objectSelection.size>1?'selection-member':''}" x="${b.x-pad}" y="${b.y-pad}" width="${b.width+pad*2}" height="${b.height+pad*2}"/>`;}
    if(objectSelection.size>1)html+=`<rect class="selection-box" x="${bounds.x-pad}" y="${bounds.y-pad}" width="${bounds.width+pad*2}" height="${bounds.height+pad*2}"/>`;
    const overlay=appendSvg(html);overlay.setAttribute('pointer-events','none');
    const only=objectSelection.size===1?entity([...objectSelection][0]):null;
    if(only&&!only.children&&!objectLocked(only.id)){const size=7/scale;appendSvg(`<rect class="selection-knob" data-resize-node="${esc(only.id)}" x="${bounds.x+bounds.width+pad-size/2}" y="${bounds.y+bounds.height+pad-size/2}" width="${size}" height="${size}"/>`);}
  }
  for(const line of objectGuides){const path=line.axis==='x'?`M${line.position} ${line.start}V${line.end}`:`M${line.start} ${line.position}H${line.end}`;appendSvg(`<path class="object-guide" pointer-events="none" d="${path}"/>`);}
  if(objectMarquee)appendSvg(`<rect class="object-marquee" pointer-events="none" x="${objectMarquee.x}" y="${objectMarquee.y}" width="${objectMarquee.width}" height="${objectMarquee.height}"/>`);
  $('alignmentHint').textContent=objectGuides.length?objectGuides.map(g=>g.label).join(' · '):objectSelection.size>1?`已选 ${objectSelection.size} 项 · 整体拖动 · Alt 关闭吸附`:objectSelection.size?'拖动位置 · 自动对齐 · Alt 关闭吸附':'点击或框选组件 · Ctrl 增选';
  $('canvasSize').textContent=`${Math.round(g.w)} × ${Math.round(g.h)} 比例画布`;
}
function computeObjectSnap(bounds,delta,references,tolerance){
  const result={x:delta.x,y:delta.y,guides:[]};
  for(const axis of ['x','y']){
    const size=axis==='x'?'width':'height',cross=axis==='x'?'y':'x',crossSize=axis==='x'?'height':'width';let best=null;
    for(const ref of references)for(let a=0;a<3;a++)for(let b=0;b<3;b++){
      // Prefer like-for-like edges/centers. Opposite edges can abut; a center
      // must not steal an edge alignment merely because it is one pixel nearer.
      if((a===1)!==(b===1))continue;
      const source=bounds[axis]+delta[axis]+bounds[size]*a/2,target=ref[axis]+ref[size]*b/2,difference=target-source;
      const priority=a===b?0:1;
      if(Math.abs(difference)>tolerance||best&&(priority>best.priority||priority===best.priority&&Math.abs(difference)>=Math.abs(best.difference)))continue;
      const label=a===b?(axis==='x'?['左边缘对齐','水平居中对齐','右边缘对齐'][a]:['上边缘对齐','垂直居中对齐','下边缘对齐'][a]):'边缘吸附';
      best={difference,priority,axis,position:target,start:Math.min(bounds[cross]+delta[cross],ref[cross])-12,end:Math.max(bounds[cross]+delta[cross]+bounds[crossSize],ref[cross]+ref[crossSize])+12,label:ref.kind==='photo'?'照片'+label:label};
    }
    if(best){result[axis]+=best.difference;result.guides.push(best);}
  }
  return result;
}
function constrainObjectDelta(leaves,delta,g=geometry()){
  let minX=-Infinity,maxX=Infinity,minY=-Infinity,maxY=Infinity;
  for(const n of leaves){const a=anchorRect(n,g),p=nodePoint(n,g);minX=Math.max(minX,a.x-p.x);maxX=Math.min(maxX,a.x+a.w-p.x);minY=Math.max(minY,a.y-p.y);maxY=Math.min(maxY,a.y+a.h-p.y);}
  return{x:clamp(delta.x,minX,maxX),y:clamp(delta.y,minY,maxY)};
}
function translateObjects(originals,delta){for(const original of originals){const n=entity(original.id),a=anchorRect(original),p=nodePoint(original);n.x=(p.x+delta.x-a.x)/Math.max(1,a.w)*100;n.y=(p.y+delta.y-a.y)/Math.max(1,a.h)*100;}}

// Re-express the same canvas point in another reference rectangle.
function changeNodeAnchor(n,anchor,g=geometry(),point=nodePoint(n,g)){
  n.anchor=anchor==='bottom'&&!g.b.bottom?'photo':anchor;
  const a=anchorRect(n,g);
  n.x=clamp((point.x-a.x)/a.w*100,0,100);
  n.y=clamp((point.y-a.y)/a.h*100,0,100);
}
function setBorderSize(key,value){
  const before=geometry(),moving=doc.nodes.filter(n=>n.anchor==='bottom');
  // Read the old rendered bounds before shrinking the reference area.
  const originals=moving.map(n=>({n,point:nodePoint(n,before),bounds:leafBounds(n.id)}));
  if(doc.linked)for(const side in doc.borders)doc.borders[side]=value;
  else doc.borders[key]=value;
  if(!before.b.bottom||doc.borders.bottom||!originals.length)return;
  const g=geometry(),padding=12;
  const bounds=originals.map(({n,point,bounds})=>bounds||{x:point.x-n.fontSize/2,y:point.y-n.fontSize/2,width:n.fontSize,height:n.fontSize});
  const left=Math.min(...bounds.map(b=>b.x)),right=Math.max(...bounds.map(b=>b.x+b.width));
  const top=Math.min(...bounds.map(b=>b.y)),bottom=Math.max(...bounds.map(b=>b.y+b.height));
  // Translate the whole block toward the photo's lower edge; keep spacing intact.
  const dx=right-left<=g.pw-2*padding
    ?clamp(0,g.b.left+padding-left,g.b.left+g.pw-padding-right)
    :g.b.left+g.pw/2-(left+right)/2;
  const dy=g.b.top+g.ph-padding-bottom;
  const offsetY=top+dy<g.b.top+padding&&bottom-top<=g.ph-2*padding?g.b.top+padding-top:dy;
  for(const {n,point} of originals)changeNodeAnchor(n,'photo',g,{x:point.x+dx,y:point.y+offsetY});
}
function alignmentButtons(){return `<div class="object-align-buttons">${Object.entries({left:['alignLeft','左对齐'],centerX:['alignCenter','水平居中'],right:['alignRight','右对齐'],top:['arrowUp','上对齐'],centerY:['params','垂直居中'],bottom:['arrowDown','下对齐']}).map(([key,[symbol,name]])=>`<button data-object-align="${key}" title="${name}" aria-label="组件${name}">${icon(symbol)}</button>`).join('')}</div>`;}
function renderObjectControls(){
  $('groupObjects').disabled=objectSelection.size<2;$('ungroupObjects').disabled=![...objectSelection].some(id=>entity(id)?.children);
  $('objectSelectionCount').textContent=objectSelection.size?`已选 ${objectSelection.size} 项`:'Ctrl 多选 · Shift 连选';
  $('snapObjects').classList.toggle('active',settings.snap!==false);$('snapObjects').setAttribute('aria-pressed',settings.snap!==false);
  if(objectSelection.size>1)$('footerStatus').textContent=`已选 ${objectSelection.size} 项 · ${chosenLeaves().length} 个组件`;
  const n=entity(selectedNode);if(n?.children&&objectSelection.size===1)$('footerStatus').textContent=`${n.name} · ${leafIds(n.id).length} 个组件`;
  const siblings=n?siblingsOf(n.id):[];$('layerUp').disabled=objectSelection.size!==1||objectProtected(n.id)||siblings.indexOf(n.id)===siblings.length-1;$('layerDown').disabled=objectSelection.size!==1||objectProtected(n.id)||siblings.indexOf(n.id)===0;
}
function renderObjectLayers(){
  $('layerCount').textContent=`${doc.nodes.length} 个组件`;
  $('layers').innerHTML=visibleLayerEntries().map(({id,depth,item})=>{
    const group=!!item.children,locked=objectLocked(id),visible=objectVisible(id);
    return `<div class="layer ${group?'group-layer':''} ${objectSelection.has(id)?'active':''} ${!visible?'off':''}" style="--depth:${depth}" data-layer="${esc(id)}" draggable="false" role="button" tabindex="0" aria-label="选择${esc(item.name)}" aria-pressed="${objectSelection.has(id)}"><span class="layer-grip" aria-hidden="true">${layerIcon('grip')}</span>${group?`<button data-layer-action="collapse" class="group-toggle" aria-label="${collapsedGroups.has(id)?'展开':'折叠'}${esc(item.name)}">${layerIcon(collapsedGroups.has(id)?'arrowRight':'chevronDown')}${layerIcon(collapsedGroups.has(id)?'group':'groupOpen')}</button>`:`<span class="layer-icon">${layerIcon(item.type)}</span>`}<span class="layer-text"><b>${esc(item.name)}</b><small>${group?`${leafIds(id).length} 个组件`:!content(item)?'当前照片缺失信息':locked?'已锁定':typeNames[item.type]}</small></span><button class="icon-button" data-layer-action="visible" title="${item.visible?'隐藏':'显示'}" aria-label="${item.visible?'隐藏':'显示'}${esc(item.name)}">${layerIcon(item.visible?'eye':'eyeOff')}</button><button class="icon-button" data-layer-action="locked" title="${item.locked?'解锁':'锁定'}" aria-label="${item.locked?'解锁':'锁定'}${esc(item.name)}">${layerIcon(item.locked?'lock':'unlock')}</button></div>`;
  }).join('')||'<div class="empty-hint">添加组件后，可以多选并分组。</div>';
}
function objectCommonValue(key){const values=chosenLeaves().map(id=>entity(id)[key]);return values.length&&values.every(v=>v===values[0])?values[0]:null;}
function renderObjectProperties(){
  const single=objectSelection.size===1?entity([...objectSelection][0]):null;
  const count=chosenLeaves().length,protectedSelection=[...objectSelection].some(objectProtected);
  const common=key=>objectCommonValue(key),number=(key,label,min,max,unit)=>`<label><span class="property-label">${label}</span><div class="number-field"><input data-batch-prop="${key}" aria-label="批量${label}" type="number" min="${min}" max="${max}" value="${common(key)??''}" placeholder="多个值" ${protectedSelection?'disabled':''}><span>${unit}</span></div></label>`;
  let html=`<section class="property-section"><div class="property-title">${single?.children?'图层组':`已选 ${objectSelection.size} 项`}<span class="muted">${count} 个组件</span></div>${single?.children?`<label class="property-label">组名称</label><input data-group-name aria-label="组名称" maxlength="80" value="${esc(single.name)}" ${objectLocked(single.id)?'disabled':''}>`:''}<div class="node-actions" style="margin-top:14px"><button class="neutral" data-group-action="group" ${objectSelection.size<2||protectedSelection?'disabled':''}>分组</button><button class="neutral" data-group-action="ungroup" ${![...objectSelection].some(id=>entity(id)?.children)||protectedSelection?'disabled':''}>取消分组</button></div><p class="hint">展开图层组，可单独编辑内部组件。</p></section>`;
  html+=`<section class="property-section"><div class="property-title">共同文字样式</div><label class="property-label">字体</label><select data-batch-prop="font" aria-label="批量字体" ${protectedSelection?'disabled':''}><option value="" ${common('font')===null?'selected':''}>多个值</option>${Object.entries(fontNames).map(([key,label])=>`<option value="${key}" ${common('font')===key?'selected':''}>${label}</option>`).join('')}</select><div class="field-grid">${number('fontSize','字号',8,110,'px')}${number('spacing','字间距',0,15,'px')}</div><label class="property-label">文字色值</label><input data-batch-prop="color" aria-label="批量文字色值" value="${common('color')??''}" placeholder="多个值 · #RRGGBB" maxlength="7" ${protectedSelection?'disabled':''}>${number('opacity','不透明度',0,100,'%')}<p class="hint">共同值直接显示，差异显示“多个值”。只应用实际修改的属性。</p></section>`;
  html+=`<section class="property-section"><div class="property-title">组件对齐<span class="muted">${objectSelection.size>1?'相对选区':'相对画布'}</span></div>${alignmentButtons()}<p class="hint">拖动时吸附其他组件边缘及中心。按住 Alt 临时关闭吸附。</p>${protectedSelection?'<p class="preview-warning">选区含锁定组件，请先解锁再整体编辑。</p>':''}</section><section class="property-section node-actions"><button id="duplicateNode" class="neutral" title="复制 Ctrl+J">${icon('duplicate')}复制</button><button id="deleteNode" class="neutral danger" ${protectedSelection?'disabled':''}>${icon('trash')}删除</button></section>`;
  $('properties').innerHTML=html;
}
function alignObjectSelection(kind){
  const ids=topObjectIds(objectSelection);if(!ids.length||ids.some(objectProtected)){toast('请先解锁选中的组件');return;}
  const g=geometry(),boxes=ids.map(id=>({id,b:objectBounds(id)})).filter(v=>v.b);
  const target=ids.length>1?unionObjectBounds(boxes.map(v=>v.b)):{x:0,y:0,width:g.w,height:g.h};if(!target)return;
  edit(()=>{for(const {id,b} of boxes){let dx=0,dy=0;if(kind==='left')dx=target.x-b.x;if(kind==='right')dx=target.x+target.width-b.x-b.width;if(kind==='centerX')dx=target.x+target.width/2-b.x-b.width/2;if(kind==='top')dy=target.y-b.y;if(kind==='bottom')dy=target.y+target.height-b.y-b.height;if(kind==='centerY')dy=target.y+target.height/2-b.y-b.height/2;const originals=leafIds(id).map(id=>copy(entity(id)));translateObjects(originals,constrainObjectDelta(originals,{x:dx,y:dy}));}});
}
function bindObjectEditor(){
  ensureObjectTree(doc);
  $('savePreset').innerHTML=layerIcon('savePreset')+'保存预设';
  $('apply').innerHTML='应用样式'+layerIcon('applyStyle');
  $('addLayer').innerHTML=layerIcon('add');
  $('groupObjects').innerHTML=layerIcon('groupAction')+'分组';
  $('ungroupObjects').innerHTML=layerIcon('ungroup')+'取消分组';
  $('layerUp').innerHTML=layerIcon('arrowUp')+'上移';
  $('layerDown').innerHTML=layerIcon('arrowDown')+'下移';
  $('groupObjects').onclick=groupObjectSelection;$('ungroupObjects').onclick=ungroupObjectSelection;
  $('snapObjects').onclick=()=>{settings.snap=settings.snap===false;renderObjectControls();persist();};
  $('layers').onclick=e=>{
    if(performance.now()<ignoreLayerClickUntil)return;
    const row=e.target.closest('[data-layer]');if(!row)return;
    const id=row.dataset.layer,action=e.target.closest('[data-layer-action]');
    if(action){const kind=action.dataset.layerAction;if(kind==='collapse'){collapsedGroups.has(id)?collapsedGroups.delete(id):collapsedGroups.add(id);renderLayers();return;}
      edit(()=>{const item=entity(id);item[kind]=!item[kind];});
    }else selectLayerObject(id,e);
  };
  $('layers').onkeydown=e=>{if(e.target.matches('[data-layer]')&&['Enter',' '].includes(e.key)){e.preventDefault();selectLayerObject(e.target.dataset.layer,e);}};
  $('layers').ondblclick=e=>{const row=e.target.closest('[data-layer]');if(row&&entity(row.dataset.layer)?.children){setObjectSelection([row.dataset.layer],row.dataset.layer);$('properties').querySelector('[data-group-name]')?.focus();}};
  $('properties').addEventListener('input',e=>{
    const input=e.target;
    if(input.hasAttribute('data-group-name')){
      const group=entity(selectedNode);if(!group?.children||objectLocked(group.id))return;
      if(!pending)pending=copy(doc);group.name=input.value.slice(0,80);renderLayers();updated();return;
    }
    const key=input.dataset.batchProp;if(!key||input.value===''||[...objectSelection].some(objectProtected))return;
    if(key==='color'&&!/^#[\da-f]{6}$/i.test(input.value))return;
    if(!pending)pending=copy(doc);
    for(const id of chosenLeaves()){
      const item=entity(id);
      item[key]=key==='font'||key==='color'?input.value:clamp(input.value,key==='fontSize'?8:0,key==='fontSize'?110:key==='spacing'?15:100);
    }
    renderCanvas();updated();
  });
  $('properties').addEventListener('click',e=>{
    const group=e.target.closest('[data-group-action]'),alignment=e.target.closest('[data-object-align]');
    if(group){group.dataset.groupAction==='group'?groupObjectSelection():ungroupObjectSelection();}
    if(alignment)alignObjectSelection(alignment.dataset.objectAlign);
  });

  // Handle dragging in the whole stage, including the blank area around the SVG.
  $('artboard').onpointerdown=$('artboard').onpointermove=$('artboard').onpointerup=$('artboard').onpointercancel=null;
  const zone=$('canvasZone');zone.tabIndex=0;
  const rememberArea=e=>{if(e.target.closest('.filmstrip'))editorSelectionContext='photos';else if(e.target.closest('.library,.stage,.inspector'))editorSelectionContext='objects';};
  document.addEventListener('pointerdown',rememberArea,true);document.addEventListener('focusin',rememberArea,true);
  zone.onpointerdown=e=>{
    if(canvasSpaceHeld||canvasPan)return;
    if(e.button!==0||e.target.closest('button,input,textarea,select,a,#inlineTextBox'))return;
    zone.focus({preventScroll:true});finishEdit();const handle=e.target.closest('[data-resize-node]'),hit=e.target.closest('[data-node]');
    const leaf=handle?.dataset.resizeNode||hit?.dataset.node;
    if(!e.ctrlKey&&!e.metaKey&&!e.shiftKey&&!handle&&lastCanvasClick&&(!leaf||leaf===lastCanvasClick.id)&&performance.now()-lastCanvasClick.time<450&&Math.hypot(e.clientX-lastCanvasClick.x,e.clientY-lastCanvasClick.y)<5){const id=lastCanvasClick.id;lastCanvasClick=null;objectOperation=null;startInlineText(id);e.preventDefault();return;}
    lastCanvasClick=leaf&&!handle&&!e.ctrlKey&&!e.metaKey&&!e.shiftKey?{id:leaf,time:performance.now(),x:e.clientX,y:e.clientY}:null;lastCanvasHit=leaf||null;
    const point=localPoint(e),previous=[...objectSelection],primary=selectedNode;
    if(!leaf){
      if(!e.ctrlKey&&!e.metaKey&&!e.shiftKey)setObjectSelection([],null);
      objectOperation={type:'marquee',start:point,clientX:e.clientX,clientY:e.clientY,previous,primary,add:e.ctrlKey||e.metaKey||e.shiftKey,moved:false};
    }else{
      const id=handle||objectSelection.has(leaf)?leaf:rootObject(leaf);
      if(e.ctrlKey||e.metaKey||e.shiftKey){const ids=new Set(objectSelection);if((e.ctrlKey||e.metaKey)&&ids.has(id))ids.delete(id);else ids.add(id);setObjectSelection(ids,id);e.preventDefault();return;}
      if(!objectSelection.has(id))setObjectSelection([id],id);
      if([...objectSelection].some(objectProtected)){e.preventDefault();return;}
      const originals=chosenLeaves().map(id=>copy(entity(id))),bounds=selectedBounds(),moving=new Set(originals.map(n=>n.id));
      const refs=[...doc.nodes.filter(n=>!moving.has(n.id)&&objectVisible(n.id)).map(n=>({...leafBounds(n.id),label:n.name})).filter(b=>Number.isFinite(b.x)),...(doc.groups||[]).filter(group=>!leafIds(group.id).some(id=>moving.has(id))).map(group=>objectBounds(group.id)).filter(Boolean)];
      const g=geometry();refs.push(photoAlignmentReference(g),{x:0,y:0,width:g.w,height:g.h,label:'画布'});
      const center=handle?nodePoint(entity(leaf)):null;
      objectOperation={type:handle?'resize':'move',start:point,clientX:e.clientX,clientY:e.clientY,before:copy(doc),originals,bounds,refs,previous,primary,moved:false,distance:handle?Math.max(1,Math.hypot(point.x-center.x,point.y-center.y)):0};
    }
    zone.setPointerCapture(e.pointerId);e.preventDefault();
  };
  zone.onpointermove=e=>{
    const op=objectOperation;if(!op)return;
    if(!op.moved&&Math.hypot(e.clientX-op.clientX,e.clientY-op.clientY)<4)return;
    op.moved=true;const point=localPoint(e);
    if(op.type==='marquee'){
      objectMarquee={x:Math.min(point.x,op.start.x),y:Math.min(point.y,op.start.y),width:Math.abs(point.x-op.start.x),height:Math.abs(point.y-op.start.y)};
      const contains=b=>b&&b.x>=objectMarquee.x&&b.y>=objectMarquee.y&&b.x+b.width<=objectMarquee.x+objectMarquee.width&&b.y+b.height<=objectMarquee.y+objectMarquee.height;
      const hits=doc.order.filter(id=>objectVisible(id)&&!objectProtected(id)&&contains(objectBounds(id)));
      setObjectSelection(op.add?[...op.previous,...hits]:hits,null,false);
      renderHeader();renderLayers();renderProperties();renderCanvas();return;
    }
    if(op.type==='resize'){
      const original=op.originals[0],center=nodePoint(original);
      entity(original.id).fontSize=clamp(original.fontSize*Math.hypot(point.x-center.x,point.y-center.y)/op.distance,8,110);objectGuides=[];
    }else{
      let delta=constrainObjectDelta(op.originals,{x:point.x-op.start.x,y:point.y-op.start.y});objectGuides=[];
      if(settings.snap!==false&&!e.altKey&&op.bounds){
        const snapped=computeObjectSnap(op.bounds,delta,op.refs,6/($('artboard').getScreenCTM()?.a||1));
        delta=constrainObjectDelta(op.originals,snapped);
        objectGuides=snapped.guides.filter(line=>Math.abs(delta[line.axis]-snapped[line.axis])<.01);
      }
      translateObjects(op.originals,delta);
    }
    renderCanvas();
  };
  function finishCanvas(e,cancel=false){
    const op=objectOperation;if(!op)return;objectOperation=null;objectMarquee=null;objectGuides=[];
    if(zone.hasPointerCapture(e.pointerId))zone.releasePointerCapture(e.pointerId);
    if(op.moved)lastCanvasClick=null;
    if(cancel){if(op.before)doc=op.before;setObjectSelection(op.previous,op.primary,false);}
    else if(op.before)checkpoint(op.before);
    render();
  }
  zone.onpointerup=e=>finishCanvas(e);zone.onpointercancel=e=>finishCanvas(e,true);

  let sorting=null;
  const dropHint=document.createElement('div');dropHint.className='layer-drop-hint';dropHint.hidden=true;dropHint.setAttribute('role','status');document.body.append(dropHint);
  const clearIndicators=()=>{
    $('layers').querySelectorAll('.drag-source,.drop-before,.drop-after,.drop-inside').forEach(row=>{row.classList.remove('drag-source','drop-before','drop-after','drop-inside');row.style.removeProperty('--drop-indent');delete row.dataset.dropStatus;});
    dropHint.hidden=true;
  };
  $('layers').onpointerdown=e=>{
    const row=e.target.closest('[data-layer]');if(e.button!==0||!row||e.target.closest('button')||e.ctrlKey||e.metaKey||e.shiftKey)return;
    finishEdit();const id=row.dataset.layer;
    sorting={ids:objectSelection.has(id)?topObjectIds(objectSelection):[id],primary:id,row,pointerId:e.pointerId,startX:e.clientX,startY:e.clientY,moved:false,target:null,placement:null};row.setPointerCapture(e.pointerId);
  };
  $('layers').onpointermove=e=>{
    const op=sorting;if(!op)return;if(!op.moved&&Math.hypot(e.clientX-op.startX,e.clientY-op.startY)<5)return;
    op.moved=true;e.preventDefault();clearIndicators();
    $('layers').querySelectorAll('[data-layer]').forEach(row=>row.classList.toggle('drag-source',op.ids.includes(row.dataset.layer)));
    const pane=$('layersPane'),bounds=pane.getBoundingClientRect();if(e.clientY>bounds.bottom-28)pane.scrollTop+=12;else if(e.clientY<bounds.top+28)pane.scrollTop-=12;
    const rows=[...$('layers').querySelectorAll('[data-layer]')];
    let target=rows.find(row=>{const r=row.getBoundingClientRect();return e.clientY>=r.top-2&&e.clientY<=r.bottom+2;});
    if(!target&&e.clientY>bounds.top&&e.clientY<bounds.bottom)target=rows.at(-1);
    op.target=null;if(!target||e.clientX<bounds.left||e.clientX>bounds.right)return;
    const id=target.dataset.layer;if(op.ids.includes(id)||ancestors(id).some(id=>op.ids.includes(id)))return;
    const r=target.getBoundingClientRect(),fraction=(e.clientY-r.top)/r.height;
    const slot=resolveLayerDrop(visibleLayerEntries(),id,fraction,e.clientX,r.left);
    if(!slot||op.ids.some(objectProtected)||op.ids.includes(slot.target)||ancestors(slot.target).some(id=>op.ids.includes(id)))return;
    const destination=slot.placement.startsWith('inside')?slot.target:parentId(slot.target);
    if(destination&&objectLocked(destination))return;
    const indicator=rows.find(row=>row.dataset.layer===slot.indicator);if(!indicator)return;
    op.target=slot.target;op.placement=slot.placement;
    indicator.style.setProperty('--drop-indent',slot.indent+'px');indicator.dataset.dropStatus=slot.status;indicator.classList.add('drop-'+slot.lineAt);
    dropHint.innerHTML=layerIcon(slot.inside?'dropInside':'dropOutside')+'<span>'+slot.status+'</span>';
    dropHint.style.left=Math.min(e.clientX+16,innerWidth-95)+'px';dropHint.style.top=Math.min(e.clientY+15,innerHeight-42)+'px';dropHint.hidden=false;
  };
  function finishSorting(e,cancel=false){
    const op=sorting;if(!op)return;sorting=null;clearIndicators();if(op.row.hasPointerCapture(e.pointerId))op.row.releasePointerCapture(e.pointerId);
    if(!op.moved)return;ignoreLayerClickUntil=performance.now()+250;if(cancel||!op.target)return;
    edit(()=>{if(reorderObjects(op.ids,op.target,op.placement))setObjectSelection(op.ids,op.primary,false);});
  }
  $('layers').onpointerup=e=>finishSorting(e);$('layers').onpointercancel=e=>finishSorting(e,true);

  document.addEventListener('keydown',e=>{
    if(e.target.matches('input,textarea,select')||$('modal').open)return;
    const control=e.ctrlKey||e.metaKey,key=e.key.toLowerCase(),photoArea=editorSelectionContext==='photos';
    if(control&&key==='d'&&!e.shiftKey&&!e.altKey){
      e.preventDefault();e.stopImmediatePropagation();finishEdit();
      if(photoArea){selectedPhotos.clear();renderPhotos();renderHeader();persist();}else setObjectSelection([],null);
    }
    else if(control&&key==='a'&&!e.shiftKey&&(!e.altKey||!photoArea)){
      e.preventDefault();e.stopImmediatePropagation();
      if(photoArea){selectedPhotos=new Set(photos.map((_,i)=>i));renderPhotos();renderHeader();persist();}else setObjectSelection(doc.order);
    }
    else if(control&&key==='g'){
      e.preventDefault();e.stopImmediatePropagation();if(!photoArea)e.shiftKey?ungroupObjectSelection():groupObjectSelection();
    }
    else if(photoArea&&(control&&key==='j'||['Delete','Backspace'].includes(e.key))){e.preventDefault();e.stopImmediatePropagation();}
    else if(photoArea&&['ArrowLeft','ArrowRight'].includes(e.key)){
      e.preventDefault();e.stopImmediatePropagation();const next=Math.round(clamp(current+(e.key==='ArrowLeft'?-1:1),0,photos.length-1));
      if(e.shiftKey){const range=Array.from({length:Math.abs(next-photoAnchor)+1},(_,i)=>Math.min(next,photoAnchor)+i);selectedPhotos=new Set(control?[...selectedPhotos,...range]:range);}else{selectedPhotos=new Set([next]);photoAnchor=next;}
      current=next;render();persist();$('thumbnails').querySelector(`[data-photo="${next}"]`)?.scrollIntoView({block:'nearest',inline:'nearest'});
    }
    else if(e.key==='Escape'&&sorting){e.preventDefault();e.stopImmediatePropagation();const op=sorting;sorting=null;clearIndicators();if(op.row.hasPointerCapture(op.pointerId))op.row.releasePointerCapture(op.pointerId);}
    else if(e.key==='Escape'&&objectOperation){e.preventDefault();e.stopImmediatePropagation();const op=objectOperation;objectOperation=null;objectMarquee=null;objectGuides=[];if(op.before)doc=op.before;setObjectSelection(op.previous,op.primary);}
    else if(!photoArea&&['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key)&&objectSelection.size&&!e.target.closest('[role=tablist]')){
      e.preventDefault();e.stopImmediatePropagation();if([...objectSelection].some(objectProtected))return;
      const step=(e.shiftKey?10:1)/($('artboard').getScreenCTM()?.a||1);
      edit(()=>{const originals=chosenLeaves().map(id=>copy(entity(id))),delta={x:e.key==='ArrowLeft'?-step:e.key==='ArrowRight'?step:0,y:e.key==='ArrowUp'?-step:e.key==='ArrowDown'?step:0};translateObjects(originals,constrainObjectDelta(originals,delta));});
    }
  },true);
}
