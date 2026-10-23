import React from "react";
import { t } from "../localization.js";
import { Icon } from "./controls.jsx";

export function LibraryAction({
  children,
  href,
  onClick,
  secondary = false,
  icon = "chevron",
  ...props
}) {
  const Element = href ? "a" : "button";
  return (
    <Element
      className={`library-action ${secondary ? "secondary" : "primary"}`}
      href={href}
      type={href ? undefined : "button"}
      onClick={onClick}
      {...props}
    >
      <span>{children}</span>
      <span className="library-action-arrow">
        <Icon name={icon} size={16} />
      </span>
    </Element>
  );
}
export function LibraryHero({
  eyebrow,
  title,
  description,
  children,
  projects = false,
}) {
  return (
    <section
      className={`library-hero ${projects ? "library-projects-empty" : "library-create-hero"}`}
    >
      <div className="library-intro-copy">
        <p className="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
        <p className="library-intro-description">{description}</p>
        {children}
      </div>
      <div className="library-mascot" aria-hidden="true">
        {projects && (
          <span className="library-mascot-folder">
            <Icon name="folder" size={28} />
          </span>
        )}
        <img
          src={
            projects
              ? "./playground/mascot-guide-v1.png"
              : "./playground/mascot-builder-v1.png"
          }
          alt=""
          width="1145"
          height="1374"
          decoding="async"
        />
      </div>
    </section>
  );
}
export function LibraryFeatures() {
  return (
    <div className="library-info-grid">
      <article className="library-feature">
        <span className="library-feature-icon">
          <Icon name="spark" size={21} />
        </span>
        <div>
          <h2>{t("Start with an idea")}</h2>
          <p>{t("Describe a game or choose a 2D or 3D world.")}</p>
        </div>
      </article>
      <article className="library-feature">
        <span className="library-feature-icon">
          <Icon name="cube" size={21} />
        </span>
        <div>
          <h2>{t("Make it yours")}</h2>
          <p>{t("Shape scenes, edit code and build with your assistant.")}</p>
        </div>
      </article>
      <article className="library-feature">
        <span className="library-feature-icon">
          <Icon name="cloud" size={21} />
        </span>
        <div>
          <h2>{t("Pick up where you left off")}</h2>
          <p>
            {t("Keep your projects in your account, ready for your next idea.")}
          </p>
        </div>
      </article>
    </div>
  );
}
