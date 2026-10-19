import { playgroundRoute, safeContinuation, viewPath } from './routes.js';

// Uses Studio's durable save/leave boundary for every navigation, including Back.
export function installNavigation(s, win = window) {
  let applying = false, stopped = false, queue = Promise.resolve(), pending;
  let current = playgroundRoute(win.location.href) || playgroundRoute('/games');
  function commit(route, replace = false) {
    current = route; s.route = route;
    const next = route.href;
    if (win.location.pathname + win.location.search + win.location.hash !== next)
      win.history[replace ? 'replaceState' : 'pushState']({}, '', next);
    s.emit();
  }
  async function perform(href, { replace = false, initial = false, pop = false } = {}) {
    const route = playgroundRoute(href);
    if (!route || stopped) return false;
    pending = route; applying = true;
    try {
      if (route.view === 'editor') {
        if (!s.account) {
          return await finishAccount(route, replace);
        }
        await s.open({ id: route.id });
      } else {
        const saved = await s.browseProjects(false, route.view);
        if (saved === false || !s.projectBrowser || s.libraryView !== route.view) {
          if (pop) win.history.pushState({}, '', current.href);
          return false;
        }
      }
      if (stopped) return false;
      commit(route, replace || initial); pending = null;
      return true;
    } catch (error) {
      if (pop) win.history.pushState({}, '', current.href);
      s.fail(error); return false;
    } finally { applying = false; }
  }
  async function finishAccount(route, replace) {
    const saved = await s.browseProjects(false, 'account');
    if (saved === false || !s.projectBrowser || s.libraryView !== 'account') return false;
    commit(playgroundRoute('/account?continue=' + encodeURIComponent(route.path)), replace);
    return true;
  }
  const router = {
    navigate(href, options) {
      const path = safeContinuation(href) || (playgroundRoute(href) ? href : null);
      if (!path) return Promise.resolve(false);
      queue = queue.then(() => perform(href, options));
      return queue;
    },
    opened(id) {
      if (!applying && !stopped) commit(playgroundRoute('/projects/' + encodeURIComponent(id)));
    },
    browsed(view) {
      if (!applying && !stopped) {
        const route = pending?.view === view ? pending : playgroundRoute(viewPath(view));
        if (route) commit(route);
        pending = null;
      }
    },
    async start() {
      await s.start();
      if (!stopped) await router.navigate(win.location.href, { initial: true });
    },
    stop() {
      stopped = true;
      win.removeEventListener('popstate', pop);
      win.document.removeEventListener('click', click);
      if (s.router === router) s.router = null;
    },
  };
  const pop = () => { void router.navigate(win.location.href, { pop: true }); };
  const click = event => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.altKey || event.shiftKey) return;
    const a = event.target.closest?.('a[href]');
    if (!a || a.target || a.hasAttribute('download')) return;
    const url = new URL(a.href, win.location.href);
    if (url.origin !== win.location.origin || !playgroundRoute(url.href)) return;
    event.preventDefault(); void router.navigate(url.pathname + url.search + url.hash);
  };
  s.router = router;
  win.addEventListener('popstate', pop);
  win.document.addEventListener('click', click);
  return router;
}
