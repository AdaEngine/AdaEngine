import React from "react";
import { Icon } from "./controls.jsx";
import { t, currentLanguage } from "../localization.js";

export function AttachmentChips({ items, onRemove, disabled = false }) {
  if (!items.length) return null;
  return (
    <div className="composer-attachments" aria-label={t("Attached files")}>
      {items.map((item) => (
        <div className="composer-attachment" key={item.id || item.path}>
          {item.preview ? (
            <img src={item.preview} alt="" />
          ) : (
            <span className="composer-attachment-icon">
              <Icon
                name={
                  item.kind === "audio"
                    ? "music"
                    : item.kind === "model"
                      ? "cube"
                      : item.kind === "image"
                        ? "image"
                        : "file"
                }
                size={20}
              />
            </span>
          )}
          <span className="composer-attachment-copy">
            <strong title={item.name}>{item.name}</strong>
            {item.size !== undefined && (
              <small>
                {t(
                  "{0} MB",
                  (item.size / 1024 / 1024).toLocaleString(currentLanguage(), {
                    maximumFractionDigits: 2,
                  }),
                )}
                {item.converted ? ` · ${t("Converted for your project")}` : ""}
              </small>
            )}
          </span>
          {onRemove && (
            <button
              type="button"
              aria-label={t("Remove attachment {0}", item.name)}
              disabled={disabled}
              onClick={() => onRemove(item.id || item.path)}
            >
              <Icon name="close" size={12} />
            </button>
          )}
        </div>
      ))}
    </div>
  );
}
