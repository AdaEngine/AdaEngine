export const encoder = new TextEncoder();
export const decode = (base64) => new TextDecoder().decode(bytes(base64));
export const bytes = (base64) =>
  Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
export function base64(data) {
  let text = "";
  for (let n = 0; n < data.length; n += 32768)
    text += String.fromCharCode(...data.subarray(n, n + 32768));
  return btoa(text);
}
export const encode = (text) => base64(encoder.encode(text));
export async function api(
  path,
  body,
  method = body === undefined ? "GET" : "POST",
  signal,
) {
  if (!path.startsWith("/v1/") || path.includes("..") || path.includes("://"))
    throw new Error("Недопустимый адрес API");
  const send = () =>
    fetch(path, {
      method,
      credentials: "same-origin",
      signal,
      cache: "no-store",
      headers: { "Content-Type": "application/json" },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
  let response = await send();
  if (response.status === 401) {
    const refresh = await fetch("/v1/auth/refresh", {
      method: "POST",
      credentials: "same-origin",
      signal,
    });
    if (refresh.ok) response = await send();
  }
  if (!response.ok) {
    const value = await response.json().catch(() => null),
      error = new Error(
        value?.error?.message ||
          value?.reason ||
          `Ошибка сервера: ${response.status}`,
      );
    error.status = response.status;
    throw error;
  }
  return response;
}
export async function json(path, body, method, signal) {
  const response = await api(path, body, method, signal);
  return response.status === 204 ? null : response.json();
}
export async function stream(body, signal, event) {
  const response = await api("/v1/ai/generate", body, "POST", signal),
    reader = response.body.getReader(),
    decoder = new TextDecoder();
  let pending = "";
  for (;;) {
    const { value, done } = await reader.read();
    pending += decoder.decode(value, { stream: !done });
    if (pending.length > 2 * 1024 * 1024)
      throw new Error("Слишком большой ответ провайдера");
    let end;
    while ((end = pending.indexOf("\n")) >= 0) {
      const line = pending.slice(0, end).trim();
      pending = pending.slice(end + 1);
      if (line.startsWith("data:") && line.slice(5).trim() !== "[DONE]")
        event(JSON.parse(line.slice(5)));
    }
    if (done) break;
  }
}
export async function recovery(action, account, project, value) {
  const db = await new Promise((resolve, reject) => {
    const request = indexedDB.open("ada-studio-recovery-v1", 1);
    request.onupgradeneeded = () => request.result.createObjectStore("drafts");
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  try {
    return await new Promise((resolve, reject) => {
      const tx = db.transaction(
          "drafts",
          action === "load" ? "readonly" : "readwrite",
        ),
        store = tx.objectStore("drafts"),
        key = `${account}:${project}`;
      const request =
        action === "load"
          ? store.get(key)
          : action === "save"
            ? store.put(value, key)
            : store.delete(key);
      tx.oncomplete = () => resolve(request.result ?? null);
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error);
    });
  } finally {
    db.close();
  }
}
export function download(name, data, type = "application/zip") {
  const url = URL.createObjectURL(new Blob([data], { type })),
    link = document.createElement("a");
  link.href = url;
  link.download = name;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 30000);
}
export { Preview } from "./preview.js";
