import { StudioEditor } from './studio-editor.js';
// Fixed-runtime preview host. It receives sources only, never Cloud/provider credentials.
const protocol = 'ada-studio-preview-v1';
const requestedOrigin = new URLSearchParams(location.hash.slice(1)).get('studioParent');
const config = fetch('./studio-player-config.json', {cache:'no-store',credentials:'omit'}).then(r => {
  if (!r.ok) throw new Error('Studio preview configuration unavailable');
  return r.json();
});
const originalFetch = globalThis.fetch.bind(globalThis);
const logs = [];
let ready, failed, loaded = false, frameWaiter, currentResources;
const gameReady = new Promise((resolve,reject) => {ready=resolve;failed=reject;});
gameReady.catch(()=>{});
for (const level of ['log','info','warn','error']) {
  const original = console[level].bind(console);
  console[level] = (...args) => {
    original(...args);
    const message = args.map(String).join(' ').slice(0,4096);
    logs.push(message);if(logs.length>200)logs.shift();
    if (message.includes('[AdaWebPlayer] Ready:')) ready();
    if (message.includes('[AdaWebPlayer] Startup failed:') || message.includes('[AdaWebPlayer] Load failed:')) failed(new Error(message));
  };
}
window.addEventListener('error', event => failed(new Error(event.message)));
window.addEventListener('unhandledrejection', () => failed(new Error('Game runtime failed')));
const safePath = path => typeof path === 'string' && path.length <= 512 && /^[a-zA-Z0-9_./-]+$/.test(path) && path.split('/').every(p=>p&&p!=='.'&&p!=='..');
const editor = new StudioEditor((type, value) => {
  parent.postMessage({protocol, event:'editor', type, value, revision:editor.revision}, requestedOrigin);
});
globalThis.__adaStudioPreview = true;
globalThis.__adaStudioFrameReady = id => {
  if (frameWaiter?.id === id) frameWaiter.resolve();
};

async function load(snapshot) {
  editor.cancel();editor.enabled=false;editor.svg.remove();
  if (snapshot.formatVersion !== 1 || !Array.isArray(snapshot.files) || snapshot.files.length > 512) throw new Error('Invalid source snapshot');
  const resources = new Map();let total=0;
  for (const file of snapshot.files) {
    if (!safePath(file.path) || resources.has(file.path.toLowerCase()) || typeof file.data !== 'string') throw new Error('Unsafe project file');
    const bytes = Uint8Array.from(atob(file.data), c=>c.charCodeAt(0));total+=bytes.length;
    if (bytes.length > 16*1024*1024 || total > 64*1024*1024) throw new Error('Preview project too large');
    resources.set(file.path.toLowerCase(), {path:file.path,bytes});
  }
  if (!resources.has('.ada/project.json')) throw new Error('Missing project metadata');
  const metadata=JSON.parse(new TextDecoder().decode(resources.get('.ada/project.json').bytes));
  if (metadata.build?.system!=='adascript') throw new Error('Preview supports AdaScript projects');
  const id = crypto.randomUUID();
  globalThis.__adaStudioRequestID = id;
  globalThis.__adaSoloMode = true;
  globalThis.__adaStudioEditMode = snapshot.editMode === true;
  currentResources = resources;
  const frame = new Promise((resolve,reject) => {
    const timer = setTimeout(()=>reject(new Error('AdaEngine did not render the updated scene')),90000);
    frameWaiter = {id,resolve:()=>{clearTimeout(timer);resolve();},reject:error=>{clearTimeout(timer);reject(error);}};
  });
  frame.catch(()=>{});
  try {
  if (loaded) {
    if (typeof globalThis.__adaInstallStudioFiles !== 'function' || typeof globalThis.__adaStudioReload !== 'function') throw new Error('Update the fixed AdaPlayer to enable editor scene reload');
    globalThis.__adaInstallStudioFiles([...resources.values()]);
    const error = globalThis.__adaStudioReload(id);
    if (error) throw new Error(String(error));
  } else {
  // Only fixed local runtime resources are fetched; user files are mounted from the source snapshot.
  globalThis.fetch = async (input, init) => {
    const url = new URL(typeof input === 'string' || input instanceof URL ? input : input.url, location.href);
    if (url.origin === location.origin) {
      const base = new URL('./',location.href).pathname;
      if (url.pathname === base+'ada-resource-manifest.json') {
        const response = await originalFetch(input, {...init,credentials:'omit'});
        const manifest = (await response.json()).filter(entry=>!entry.path.startsWith('game/'));
        for (const file of currentResources.values()) manifest.push({path:'game/'+file.path,url:'game/'+file.path});
        return Response.json(manifest);
      }
      if (url.pathname.startsWith(base+'game/')) {
        const path = decodeURIComponent(url.pathname.slice((base+'game/').length));
        const file=currentResources.get(path.toLowerCase());
        return file ? new Response(file.bytes) : new Response('Not found',{status:404});
      }
    }
    return originalFetch(input,{...init,credentials:'omit'});
  };
  loaded = true;
  await import('./main.js');
  await gameReady;
  }
  await frame;
  await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
  await editor.load(snapshot.editMode===true,snapshot.revision);
  return {ready:true, editMode:snapshot.editMode===true};
  } catch (error) {frameWaiter?.reject(error);throw error;}
  finally {if(frameWaiter?.id===id)frameWaiter=null;}
}

async function execute(type,payload) {
  if(type==='load')return load(payload);
  if(type==='logs')return logs;
  if(type==='editor')return editor.command(payload||{});
  const canvas=document.querySelector('canvas');
  if(!loaded||!canvas)throw new Error('Game is not ready');
  if(type==='capture') {
    await new Promise(resolve=>requestAnimationFrame(resolve));
    const image=document.createElement('canvas'), scale=Math.min(1,1024/canvas.width);
    image.width=Math.max(1,Math.round(canvas.width*scale));image.height=Math.max(1,Math.round(canvas.height*scale));
    image.getContext('2d').drawImage(canvas,0,0,image.width,image.height);
    let encoded=image.toDataURL('image/jpeg',0.65);
    for(const quality of [0.45,0.3,0.15]) {
      if(encoded.length<=96*1024)break;
      encoded=image.toDataURL('image/jpeg',quality);
    }
    if(encoded.length>96*1024)throw new Error('Camera frame exceeds the agent image budget');
    return encoded;
  }
  if(type==='input') {
    if(!['down','up','press'].includes(payload.phase)||!/^([a-zA-Z0-9]|Arrow(Left|Right|Up|Down)|Space|Enter|Escape)$/.test(payload.key||''))throw new Error('Unsupported input');
    const key=payload.key==='Space'?' ':payload.key, code=payload.key.length===1?`${/^[0-9]$/.test(payload.key)?'Digit':'Key'}${payload.key.toUpperCase()}`:payload.key;
    const dispatch=type=>canvas.dispatchEvent(new KeyboardEvent(type,{key,code,bubbles:true,cancelable:true}));
    canvas.focus();dispatch(payload.phase==='up'?'keyup':'keydown');
    if(payload.phase==='press')await new Promise(resolve=>setTimeout(()=>{dispatch('keyup');resolve();},Math.max(16,Math.min(5000,Number(payload.durationMs)||100))));
    return {ok:true};
  }
  throw new Error('Unknown preview message');
}
window.addEventListener('message',async event=>{
  if(event.source!==parent||event.origin!==requestedOrigin||event.data?.protocol!==protocol||typeof event.data.id!=='string')return;
  try {
    const settings=await config;
    if(!Array.isArray(settings.allowedOrigins)||!settings.allowedOrigins.includes(event.origin))throw new Error('Studio origin not permitted');
    const value=await execute(event.data.type,event.data.payload);
    parent.postMessage({protocol,id:event.data.id,value},event.origin);
  } catch(error) {parent.postMessage({protocol,id:event.data.id,error:error.message||'Preview failed'},event.origin);}
});
