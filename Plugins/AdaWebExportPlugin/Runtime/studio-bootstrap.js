// Startup failures can precede ES module evaluation. Keep this listener dependency-free.
(() => {
  const parentOrigin = new URLSearchParams(location.hash.slice(1)).get('studioParent');
  const report = message => {
    const label = document.getElementById('ada-loader-status');
    if (!label || label.closest('#ada-loader')?.dataset.state === 'hidden') return;
    if (label) label.textContent = String(message).slice(0, 2000);
    if (parentOrigin) parent.postMessage({protocol:'ada-studio-preview-v1',event:'startup-error',message:String(message).slice(0,2000)},parentOrigin);
  };
  window.addEventListener('error', event => report(event.message || 'Unable to load Player module'));
  window.addEventListener('unhandledrejection', event => report(event.reason?.message || 'Player startup failed'));
})();
