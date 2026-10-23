// Browser capabilities for the AdaUI/WASM shell. No editor UI or agent loop lives here.
const controllers = new Set();
const generations = new Set();
let frame, previewPending = new Map(), previewBounds, previewOrigin, previewEpoch = 0, cancelFrameLoad;
const base64 = bytes => {
  let text = '';
  for (let n = 0; n < bytes.length; n += 32768) text += String.fromCharCode(...bytes.subarray(n, n + 32768));
  return btoa(text);
};
const unbase64 = value => Uint8Array.from(atob(value), c => c.charCodeAt(0));
const safePath = path => typeof path === 'string' && /^[a-zA-Z0-9_./-]+$/.test(path) && path.length <= 512 && path.split('/').every(p => p && p !== '.' && p !== '..');

async function http(path, method, body, signal) {
  if (!path.startsWith('/v1/') || path.includes('://') || path.includes('..')) throw new Error('Invalid API path');
  const send = () => fetch(path, {method, credentials: 'same-origin', cache: 'no-store', signal,
    headers: {'Content-Type': 'application/json'}, ...(body == null ? {} : {body: JSON.stringify(body)})});
  let response = await send();
  if (response.status === 401) {
    const refresh = await fetch('/v1/auth/refresh', {method: 'POST', credentials: 'same-origin', signal});
    if (refresh.ok) response = await send();
  }
  if (!response.ok) {
    const error = await response.json().catch(() => null);
    const e = new Error(error?.error?.message || error?.reason || `HTTP ${response.status}`);
    e.status = response.status; throw e;
  }
  return response;
}

async function database() {
  return new Promise((resolve, reject) => {
    const open = indexedDB.open('ada-studio-recovery-v1', 1);
    open.onupgradeneeded = () => open.result.createObjectStore('drafts');
    open.onsuccess = () => resolve(open.result);
    open.onerror = () => reject(open.error);
  });
}
async function recovery(action, args) {
  if (!args.account || !args.project) throw new Error('Recovery requires an account and project');
  const db = await database();
  try {
    return await new Promise((resolve, reject) => {
      const tx = db.transaction('drafts', action === 'load' ? 'readonly' : 'readwrite');
      const store = tx.objectStore('drafts'), key = `${args.account}:${args.project}`;
      const req = action === 'load' ? store.get(key) : action === 'save' ? store.put(args.value, key) : store.delete(key);
      tx.oncomplete = () => resolve(action === 'load' ? req.result ?? null : null);
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error || new Error('Recovery write aborted'));
    });
  } finally { db.close(); }
}

function stopPreview() {
  previewEpoch += 1;
  cancelFrameLoad?.(); cancelFrameLoad = null;
  frame?.remove(); frame = null;
  for (const pending of previewPending.values()) pending.reject(new Error('Предпросмотр остановлен.'));
  previewPending.clear();
}
function layoutPreview() {
  if (!frame || !previewBounds) return;
  const b = previewBounds;
  Object.assign(frame.style, {position: 'fixed', left: `${b.x}px`, top: `${b.y}px`, width: `${Math.max(0,b.width)}px`,
    height: `${Math.max(0,b.height)}px`, border: '1px solid #2a384c', borderRadius: '8px', zIndex: '10',
    display: b.visible ? 'block' : 'none', background: '#10161f'});
}
async function previewMessage(type, payload) {
  if (!frame?.contentWindow) throw new Error('Сначала запустите игру.');
  const id = crypto.randomUUID();
  return await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => { previewPending.delete(id); reject(new Error('Предпросмотр не отвечает.')); }, type === 'load' ? 120000 : 30000);
    previewPending.set(id, {resolve: value => {clearTimeout(timeout);resolve(value);}, reject: e => {clearTimeout(timeout);reject(e);}});
    frame.contentWindow.postMessage({protocol:'ada-studio-preview-v1',id,type,payload}, previewOrigin);
  });
}
window.addEventListener('message', event => {
  if (event.source !== frame?.contentWindow || event.origin !== previewOrigin || event.data?.protocol !== 'ada-studio-preview-v1') return;
  const pending = previewPending.get(event.data.id);
  if (!pending) return;
  previewPending.delete(event.data.id);
  event.data.error ? pending.reject(new Error(event.data.error)) : pending.resolve(event.data.value);
});

async function execute(method, args, notify) {
  if (method === 'network.wait') {
    if (!navigator.onLine) await new Promise(resolve => window.addEventListener('online', resolve, {once:true}));
    await new Promise(resolve => setTimeout(resolve, 5000));
    return null;
  }
  if (method === 'auth.wait') {
    for (let n=0;n<150;n++) {
      const response=await fetch('/v1/me',{credentials:'same-origin',cache:'no-store'});
      if(response.ok)return response.json();
      await new Promise(resolve=>setTimeout(resolve,2000));
    }
    throw new Error('Вход не завершён. Повторите попытку.');
  }
  if (method === 'request' || method === 'stream') {
    const controller = new AbortController(); controllers.add(controller);
    if (method === 'stream') generations.add(controller);
    try {
      const response = await http(args.path, method === 'stream' ? 'POST' : args.method || 'GET', args.body, controller.signal);
      if (method === 'request') return response.status === 204 ? null : await response.json();
      const reader = response.body.getReader(), decoder = new TextDecoder();
      let pending = '';
      while (true) {
        const {done,value} = await reader.read();
        pending += decoder.decode(value, {stream: !done});
        if (pending.length > 2 * 1024 * 1024) throw new Error('Provider event too large');
        let end;
        while ((end = pending.indexOf('\n')) >= 0) {
          const line = pending.slice(0,end).trim();pending = pending.slice(end+1);
          if (line.startsWith('data:') && line.slice(5).trim() !== '[DONE]') notify(JSON.parse(line.slice(5)));
        }
        if (done) break;
      }
      return null;
    } finally { controllers.delete(controller); generations.delete(controller); }
  }
  if (method.startsWith('recovery.')) return recovery(method.split('.')[1], args);
  if (method === 'digest') return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',unbase64(args)))).map(b=>b.toString(16).padStart(2,'0')).join('');
  if (method === 'media.upload') {
    if (!/^data:image\/(jpeg|png);base64,/.test(args.image)) throw new Error('Invalid cover image');
    const response = await fetch('/v1/media',{method:'POST',credentials:'same-origin',headers:{'Content-Type':'image/jpeg'},body:unbase64(args.image.split(',')[1])});
    if (!response.ok) throw new Error(`Cover upload HTTP ${response.status}`);
    return response.json();
  }
  if (method === 'file.open') {
    const file = await new Promise(resolve => {
      const input = document.createElement('input'); input.type = 'file'; input.accept = args.accept || '.zip';
      input.onchange = () => {resolve(input.files[0] ?? null);input.remove();};
      input.oncancel = () => {resolve(null);input.remove();};
      input.style.display = 'none';document.body.append(input);input.click();
    });
    if (!file) return null;
    if (file.size > 65 * 1024 * 1024) throw new Error('Файл превышает 65 МБ.');
    return {path: file.name, data: base64(new Uint8Array(await file.arrayBuffer()))};
  }
  if (method === 'preview.load') {
    stopPreview();
    const epoch = previewEpoch;
    const config = await (await http('/v1/ai/studio-config','GET',null)).json();
    if (epoch !== previewEpoch) throw new Error('Предпросмотр остановлен.');
    const url = new URL(config.previewURL);
    // Cookies are host-scoped, not port-scoped: another port on the Cloud host is insufficient.
    const loopback = host => ['localhost','127.0.0.1','[::1]'].includes(host);
    const localHTTP = location.protocol === 'http:' && url.protocol === 'http:' && loopback(location.hostname) && loopback(url.hostname);
    if ((url.protocol !== 'https:' && !localHTTP) || url.hostname === location.hostname || url.username || url.password) throw new Error('Preview requires a separate HTTPS host');
    previewOrigin = url.origin;
    url.hash = new URLSearchParams({studioParent: location.origin}).toString();
    frame = document.createElement('iframe');frame.title = 'Игра Ada Studio';
    frame.setAttribute('sandbox', 'allow-scripts allow-same-origin allow-pointer-lock');
    frame.allow = 'autoplay; fullscreen';frame.referrerPolicy = 'no-referrer';
    const loaded = new Promise((resolve,reject) => {
      const timer = setTimeout(() => reject(new Error('Не удалось загрузить Web Player.')),30000);
      cancelFrameLoad = () => {clearTimeout(timer);reject(new Error('Предпросмотр остановлен.'));};
      frame.onload = () => {clearTimeout(timer);resolve();};frame.onerror = () => {clearTimeout(timer);reject(new Error('Web Player unavailable'));};
    });
    frame.src = url.href;document.body.append(frame);layoutPreview();await loaded;
    if (epoch !== previewEpoch) throw new Error('Предпросмотр остановлен.');
    cancelFrameLoad = null;
    if (args.files.length > 512 || args.files.some(f => !safePath(f.path))) throw new Error('Invalid preview snapshot');
    return previewMessage('load', args);
  }
  if (method === 'preview.capture') return previewMessage('capture');
  if (method === 'preview.input') return previewMessage('input', args);
  if (method === 'preview.logs') return previewMessage('logs');
  if (method === 'upload') {
    const url = new URL(args.url);
    if (url.protocol !== 'https:') throw new Error('Upload requires HTTPS');
    const response = await fetch(url, {method:'PUT', credentials:'omit', headers:{'Content-Type':args.contentType || 'application/zip'},body:unbase64(args.data)});
    if (!response.ok) throw new Error(`Upload HTTP ${response.status}`);
    return null;
  }
  throw new Error(`Unknown browser operation: ${method}`);
}

globalThis.adaStudio = {
  call(method, json, callback) {
    const emit = message => callback(JSON.stringify(message));
    Promise.resolve().then(() => execute(method, JSON.parse(json), value => emit({kind:'event',value})))
      .then(value => emit({kind:'done',value:value ?? null}), error => emit({kind:'error',status:error.status || 0,message:error.message || 'Browser operation failed'}));
  },
  fire(method, json) {
    const args = JSON.parse(json);
    if (method === 'cancel') {for (const controller of generations) controller.abort();}
    else if (method === 'preview.stop') stopPreview();
    else if (method === 'preview.bounds') {previewBounds = args;layoutPreview();}
    else if (method === 'signin') window.open('/cloud','_blank','noopener');
    else if (method === 'file.download') {
      const url = URL.createObjectURL(new Blob([unbase64(args.data)], {type:'application/zip'}));
      const link = document.createElement('a');link.href=url;link.download=args.name;link.click();setTimeout(()=>URL.revokeObjectURL(url),30000);
    }
  }
};
window.addEventListener('pagehide', () => {for (const controller of controllers) controller.abort();stopPreview();});
if (!navigator.gpu) {
  const message = document.createElement('p');message.textContent = 'Ada Studio требует настольный браузер с WebGPU. Обновите браузер и включите аппаратное ускорение.';
  message.style.cssText='position:fixed;inset:0;display:grid;place-content:center;background:#10161f;color:white;font:18px system-ui;padding:32px;z-index:1000';document.body.append(message);
}
