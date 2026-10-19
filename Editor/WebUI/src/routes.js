// Public Playground URLs. API, Store and Console URLs are deliberately not routes.
const id = '[A-Za-z0-9_-]+';
export function playgroundRoute(value) {
  const url = new URL(value, 'http://playground.local');
  let path = url.pathname.replace(/\/+$/, '') || '/';
  if (path === '/' || path === '/studio') path = '/games';
  else if (path === '/games/create') path = '/create';
  else if (path === '/cloud') path = '/account';
  else if (path === '/cloud/admin') path = '/account/admin';
  else if (path === '/cloud/projects' || path.startsWith('/cloud/projects/'))
    path = path.replace('/cloud/projects', '/publications');
  let view, key;
  if (path === '/games') view = 'games';
  else if (new RegExp(`^/games/(${id})$`).test(path)) { view = 'games'; key = path.split('/')[2]; }
  else if (path === '/create') view = 'create';
  else if (path === '/projects') view = 'projects';
  else if (new RegExp(`^/projects/(${id})$`).test(path)) { view = 'editor'; key = path.split('/')[2]; }
  else if (path === '/account' || path === '/account/admin') view = 'account';
  else if (path === '/publications' || new RegExp(`^/publications/(${id})$`).test(path)) view = 'publications';
  else if (/^\/legal\/(terms|privacy|gdpr)$/.test(path)) view = 'legal';
  else return null;
  return { view, id: key, path, href: path + url.search + url.hash };
}
export function viewPath(view) {
  return ({ games: '/games', create: '/create', projects: '/projects', account: '/account', publications: '/publications', legal: '/legal/terms' })[view];
}
export function safeContinuation(value) {
  if (typeof value !== 'string' || !value.startsWith('/') || value.startsWith('//') || /[\\%?#\s]/.test(value) || value.includes('..')) return null;
  const route = playgroundRoute(value);
  return route && ['games', 'create', 'projects', 'editor', 'publications'].includes(route.view) ? route.path : null;
}
