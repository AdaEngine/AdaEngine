import { test } from 'node:test';
import assert from 'node:assert/strict';
import { installNavigation } from '../src/navigation.js';
function setup(path = '/games', account = { id: 'me' }) {
  const listeners = new Map();
  let url = new URL(path, 'https://cloud.example');
  const win = { get location() { return url; }, document: { addEventListener() {}, removeEventListener() {} }, addEventListener: (k, f) => listeners.set(k, f), removeEventListener: k => listeners.delete(k), history: { pushState: (_, __, p) => { url = new URL(p, url); }, replaceState: (_, __, p) => { url = new URL(p, url); } } };
  const s = { account, libraryView: 'games', projectBrowser: true, emit() {}, start: async () => {}, fail(e) { this.error = e.message; }, async browseProjects(_, view) { if (this.failSave) { this.leavePrompt = 'save failed'; return false; }; this.projectBrowser = true; this.libraryView = view; }, async open({ id }) { if (this.failSave) throw new Error('save failed'); this.opened = id; this.projectBrowser = false; } };
  const router = installNavigation(s, win);
  return { win, s, router, listeners, setURL: p => { url = new URL(p, url); } };
}
test('legacy entry and deep links use the same shell, including reload', async () => {
  const h = setup('/studio/'); await h.router.start(); assert.equal(h.win.location.pathname, '/games');
  await h.router.navigate('/projects/private-1'); assert.equal(h.s.opened, 'private-1');
  const reload = setup(h.win.location.pathname); await reload.router.start(); assert.equal(reload.s.opened, 'private-1');
});
test('private deep link requires sign-in and preserves destination', async () => {
  const h = setup('/projects/private-1', null); await h.router.start();
  assert.equal(h.win.location.pathname, '/account');
  assert.equal(h.win.location.searchParams.get('continue'), '/projects/private-1');
});
test('failed durable save does not change the current screen or URL', async () => {
  const h = setup(); await h.router.start(); h.s.failSave = true;
  assert.equal(await h.router.navigate('/account'), false);
  assert.equal(h.win.location.pathname, '/games');
  assert.equal(h.s.route.view, 'games');
  h.s.failSave = false; h.router.browsed('account'); assert.equal(h.win.location.pathname, '/account');
});
test('Back navigation goes through the same save guard and restores URL on failure', async () => {
  const h = setup('/projects/private-1'); await h.router.start();
  h.s.failSave = true; h.setURL('/games');
  await h.router.navigate('/games', { pop: true });
  assert.equal(h.win.location.pathname, '/projects/private-1');
});
test('publication details keep their route while account and game navigation work', async () => {
  const h = setup(); await h.router.start();
  for (const p of ['/publications/page-1', '/account', '/legal/terms', '/games/game-1']) { assert(await h.router.navigate(p)); assert.equal(h.win.location.pathname, p); }
  h.router.stop(); assert.equal(await h.router.navigate('/create'), false);
});

test('a failed save also blocks detail navigation within the same library view', async () => {
  const h = setup(); await h.router.start(); h.s.failSave = true;
  assert.equal(await h.router.navigate('/games/another'), false);
  assert.equal(h.win.location.pathname, '/games');
});
