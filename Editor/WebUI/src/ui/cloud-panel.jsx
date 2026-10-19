import React, { useEffect, useRef, useState } from "react";
import { studio } from "./state.js";
import { t, currentLanguage } from "../localization.js";
import "../cloud-panel.css";
let panels;
function loadPanels() {
  if (!panels) {
    const style = document.createElement("link");
    style.rel = "stylesheet";
    style.href = new URL("cloud-panels.css", document.baseURI).href;
    document.head.append(style);
    panels = import(new URL("cloud-panels.js", document.baseURI).href).catch(error => {
      style.remove(); panels = undefined; throw error;
    });
  }
  return panels;
}
export function CloudPanel({ route }) {
  const host = useRef();
  const language = currentLanguage();
  const [error, setError] = useState(false), [retry, setRetry] = useState(0);
  useEffect(() => {
    let live = true, unmount;
    setError(false);
    loadPanels().then(module => {
      if (!live) return;
      unmount = module.mountCloudPanel(host.current, {
        translate: t,
        getLanguage: currentLanguage,
        onNavigate: (path, options) => studio.router.navigate(path, options),
        onAuthenticated: async account => {
          if (!live) return;
          if (studio.account?.id !== account?.id) {
            studio.preview.stop();
            studio.document = null; studio.workspace = null; studio.projects = [];
          }
          if (account && !studio.account) await studio.start();
          studio.account = account;
          if (!account) studio.status = "signedout";
          studio.emit();
        },
      });
    }).catch(() => { if (live) setError(true); });
    return () => { live = false; unmount?.(); };
  }, [route.href, retry]);
  useEffect(() => {
    let active = true;
    if (panels) panels.then(module => { if (active) module.updateCloudPanelLanguage?.(); }).catch(() => {});
    return () => { active = false; };
  }, [language]);
  return <main className="playground-cloud-panel">
    {error && <div role="alert"><p>{t("We could not load your workspace. Check your connection and try again.")}</p><button onClick={() => setRetry(n => n + 1)}>{t("Try again")}</button></div>}
    <div ref={host} />
  </main>;
}
