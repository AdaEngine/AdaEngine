import React from "react";
import { studio } from "./state.js";

const paths = {
  music:
    "M9 18V5l12-3v13M9 5l12-3M9 18a3 3 0 1 1-3-3c1.7 0 3 1.3 3 3m12-3a3 3 0 1 1-3-3c1.7 0 3 1.3 3 3",
  user: "M20 21v-2a7 7 0 0 0-14 0v2M13 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8",
  users:
    "M16 21v-2a6 6 0 0 0-12 0v2M10 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8m9 0a4 4 0 0 1 0 8m3 10v-2a6 6 0 0 0-3-5.2",
  terminal: "M3 4h18v16H3Zm4 4 4 4-4 4m6 0h4",
  annotate: "M4 4h16v12H9l-5 4Zm4 4h8m-8 4h5",
  snap: "M4 3v10a8 8 0 0 0 16 0V3h-5v10a3 3 0 0 1-6 0V3Zm0 5h5m6 0h5",
  focus: "M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5M9 9h6v6H9Z",
  reset: "M3 11a9 9 0 1 1 2 7M3 4v7h7",
  help: "M9 9a3 3 0 1 1 5 2l-2 2v1m0 3h.01M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20",
  home: "M3 10 12 3l9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1Z",
  cube: "m12 3 9 5v9l-9 5-9-5V8Zm0 10v9M3 8l9 5 9-5M7.5 5.5l9 5",
  spark: "m12 3 2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5Z",
  play: "m8 5 11 7-11 7Z",
  stop: "M6 6h12v12H6Z",
  code: "m8 7-5 5 5 5m8-10 5 5-5 5m-3-13-2 16",
  folder: "M3 6h6l2 2h10v12H3Z",
  image: "M3 4h18v16H3Zm0 12 6-6 5 5 3-3 4 4M15 8h.01",
  plus: "M12 5v14M5 12h14",
  minus: "M5 12h14",
  close: "m6 6 12 12M6 18 18 6",
  chevron: "m9 5 7 7-7 7",
  down: "m6 9 6 6 6-6",
  search: "m20 20-5-5M10 3a7 7 0 1 0 0 14 7 7 0 0 0 0-14",
  history: "M3 11a9 9 0 1 1 2 7M3 4v7h7m2-5v6l4 2",
  download: "M12 3v12m-5-5 5 5 5-5M4 17v4h16v-4",
  upload: "M12 16V3m-5 5 5-5 5 5M4 17v4h16v-4",
  settings: "M4 6h16M4 12h16M4 18h16M8 3v6m8 0v6M8 15v6",
  arrow: "M12 19V5m-6 6 6-6 6 6",
  move: "M12 3v18M3 12h18M9 6l3-3 3 3M9 18l3 3 3-3M6 9l-3 3 3 3m12-6 3 3-3 3",
  rotate: "M20 8a9 9 0 1 0 1 6m-1-11v5h-5",
  scale: "M4 4h7m-7 0v7m0-7 7 7m9 9h-7m7 0v-7m0 7-7-7",
  check: "m5 12 4 4L19 6",
  cloud: "M6 18a5 5 0 1 1 0-10 7 7 0 0 1 13 2 4 4 0 0 1-1 8Z",
  monitor: "M3 4h18v13H3Zm9 13v4m-5 0h10",
  phone: "M7 2h10v20H7Zm4 17h2",
  camera: "M3 7h5l2-3h4l2 3h5v13H3Zm9 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8",
  more: "M12 5h.01M12 12h.01M12 19h.01",
  undo: "M4 10h9a7 7 0 0 1 7 7M4 10l5-5m-5 5 5 5",
  redo: "M20 10h-9a7 7 0 0 0-7 7m16-7-5-5m5 5-5 5",
  file: "M5 3h9l5 5v13H5Zm9 0v6h5",
  light:
    "M12 2v2m0 16v2M2 12h2m16 0h2M5 5l2 2m10 10 2 2M5 19l2-2M17 7l2-2M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10",
  trash: "M3 6h18M5 6l1 15h12l1-15M9 6V3h6v3m-5 4v7m4-7v7",
  link: "m8 16 8-8m-9 5-2 2a4 4 0 0 0 6 6l3-3m-4-12 3-3a4 4 0 0 1 6 6l-2 2",
};
function Icon({ name, size = 18, ...props }) {
  return (
    <svg
      width={`${size / 13}rem`}
      height={`${size / 13}rem`}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.65"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      {...props}
    >
      <path d={paths[name] || paths.cube} />
    </svg>
  );
}
function Mark({ size = 32 }) {
  return (
    <img
      className="brand-mark"
      src="./ada-logo.svg"
      style={{ "--mark-size": `${size / 13}rem` }}
      alt=""
      aria-hidden="true"
      draggable="false"
    />
  );
}
function Button({
  icon,
  label,
  children,
  className = "",
  active = false,
  ...props
}) {
  return (
    <button
      className={`${children ? "button" : "icon-button"} ${active ? "active" : ""} ${className}`}
      title={label}
      aria-label={label}
      aria-pressed={active || undefined}
      {...props}
    >
      {icon && <Icon name={icon} />}
      {children}
    </button>
  );
}
const act = (fn) => () => studio.action(fn);
const entityIcon = (e) =>
  Object.keys(e.components).some((k) => k.includes("Camera"))
    ? "camera"
    : Object.keys(e.components).some((k) => k.includes("Light"))
      ? "light"
      : "cube";

export { Icon, Mark, Button, act, entityIcon };
