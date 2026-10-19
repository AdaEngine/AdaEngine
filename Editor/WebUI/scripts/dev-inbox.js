// Served only by dev-cloud.py; language resolution is the production preference helper.
import { currentLanguage } from "/__dev/localization.js";

const link = document.createElement("a");
link.className = "dev-inbox-link";
link.href = "http://127.0.0.1:28088/";
link.target = "_blank";
link.rel = "noopener noreferrer";
link.hidden = true;
link.innerHTML =
  '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><path d="M3 5h18v14H3ZM3 5l9 7 9-7"/></svg>';
const caption = document.createElement("span");
link.append(caption);
const style = document.createElement("style");
style.textContent = `
.dev-inbox-link{position:fixed;right:1rem;bottom:1rem;z-index:80;display:inline-flex;align-items:center;justify-content:center;gap:.5rem;max-width:calc(100% - 2rem);padding:.65rem .9rem;border:1px solid #9585cc60;border-radius:.6rem;background:#282332;color:#e1d8ff;font:500 13px/1.4 system-ui;text-decoration:none;box-shadow:0 4px 18px #0004}
.dev-inbox-link:hover{background:#353044;color:#fff}
.dev-inbox-link[hidden]{display:none}
.dev-inbox-link.inline{position:static;right:auto;bottom:auto;margin:.7rem 0;box-shadow:none}
`;
document.head.append(style);
document.body.append(link);
let scheduled = false;
function update() {
  scheduled = false;
  const label = inboxLabels[currentLanguage()] || inboxLabels.en;
  if (caption.textContent !== label) caption.textContent = label;
  const code = Array.from(
    document.querySelectorAll('input[autocomplete="one-time-code"]'),
  ).find((node) => node.getClientRects().length);
  const visible =
    !!code || /^\/(?:account|cloud)(?:\/|$)/.test(location.pathname);
  if (link.hidden === visible) link.hidden = !visible;
  const className = `dev-inbox-link${code ? " inline" : ""}`;
  if (link.className !== className) link.className = className;
  const anchor = code?.closest("label") || code;
  if (anchor && anchor.nextElementSibling !== link)
    anchor.insertAdjacentElement("afterend", link);
  else if (!anchor && link.parentElement !== document.body)
    document.body.append(link);
}
function refresh() {
  if (!scheduled) {
    scheduled = true;
    requestAnimationFrame(update);
  }
}
new MutationObserver(refresh).observe(document.body, {
  childList: true,
  subtree: true,
  characterData: true,
  attributes: true,
  attributeFilter: ["hidden", "class"],
});
window.addEventListener("popstate", refresh);
window.addEventListener("storage", refresh);
document.addEventListener("change", refresh);
update();
