import React, {
  useEffect,
  useId,
  useLayoutEffect,
  useRef,
  useState,
} from "react";
import { createPortal } from "react-dom";
import { Icon } from "./controls.jsx";

const usePickerLayoutEffect =
  typeof document === "undefined" ? useEffect : useLayoutEffect;

export function CreationPicker({ label, value, options, onChange, disabled }) {
  const id = useId(),
    trigger = useRef(),
    menu = useRef(),
    items = useRef([]);
  const [open, setOpen] = useState(false),
    [active, setActive] = useState(0);
  const [position, setPosition] = useState(null);
  const selected = Math.max(
    0,
    options.findIndex((option) => option.value === value),
  );
  const current = options[selected];
  const close = (restore = false) => {
    setOpen(false);
    if (restore) trigger.current?.focus();
  };
  const show = () => {
    setActive(selected);
    setOpen(true);
  };
  useEffect(() => {
    if (disabled) setOpen(false);
  }, [disabled]);
  usePickerLayoutEffect(() => {
    if (!open) return;
    const place = () => {
      const bounds = trigger.current.getBoundingClientRect();
      const width = Math.min(272, window.innerWidth - 24);
      const height = menu.current?.offsetHeight || 184;
      const below = bounds.bottom + 8;
      setPosition({
        width,
        left: Math.max(
          12,
          Math.min(bounds.left, window.innerWidth - width - 12),
        ),
        top: Math.max(
          12,
          Math.min(
            bounds.top >= height + 20 ? bounds.top - height - 8 : below,
            window.innerHeight - height - 12,
          ),
        ),
      });
    };
    place();
    const outside = (event) => {
      if (
        !trigger.current?.contains(event.target) &&
        !menu.current?.contains(event.target)
      )
        close();
    };
    document.addEventListener("pointerdown", outside, true);
    document.addEventListener("focusin", outside);
    window.addEventListener("resize", place);
    window.addEventListener("scroll", place, true);
    return () => {
      document.removeEventListener("pointerdown", outside, true);
      document.removeEventListener("focusin", outside);
      window.removeEventListener("resize", place);
      window.removeEventListener("scroll", place, true);
    };
  }, [open, label]);
  usePickerLayoutEffect(() => {
    if (open && position) items.current[active]?.focus();
  }, [open, active, !!position]);
  const choose = (option) => {
    onChange(option.value);
    close(true);
  };
  return (
    <>
      <button
        ref={trigger}
        type="button"
        className={`creation-picker ${open ? "is-open" : ""}`}
        aria-label={label}
        aria-describedby={`${id}-value`}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={open ? id : undefined}
        disabled={disabled}
        onClick={() => (open ? close() : show())}
        onKeyDown={(event) => {
          if (["ArrowDown", "ArrowUp"].includes(event.key)) {
            event.preventDefault();
            show();
          }
        }}
      >
        <Icon name={current.icon} size={14} />
        <span id={`${id}-value`}>{current.label}</span>
        <Icon name="down" size={11} />
      </button>
      {open &&
        createPortal(
          <div
            ref={menu}
            id={id}
            role="menu"
            aria-label={label}
            className="creation-picker-menu"
            style={{ ...position, visibility: position ? "visible" : "hidden" }}
            onKeyDown={(event) => {
              if (event.key === "Escape") {
                event.preventDefault();
                event.stopPropagation();
                close(true);
              } else if (event.key === "Tab") close(true);
              else if (
                ["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)
              ) {
                event.preventDefault();
                setActive(
                  event.key === "Home"
                    ? 0
                    : event.key === "End"
                      ? options.length - 1
                      : (active +
                          (event.key === "ArrowDown"
                            ? 1
                            : options.length - 1)) %
                        options.length,
                );
              }
            }}
          >
            <div className="creation-picker-heading">{label}</div>
            {options.map((option, index) => (
              <button
                type="button"
                role="menuitemradio"
                aria-checked={option.value === value}
                tabIndex={index === active ? 0 : -1}
                key={option.value}
                ref={(node) => {
                  items.current[index] = node;
                }}
                className={index === active ? "is-active" : ""}
                onFocus={() => setActive(index)}
                onClick={() => choose(option)}
              >
                <span className="creation-picker-icon">
                  <Icon name={option.icon} size={19} />
                </span>
                <span className="creation-picker-copy">
                  <strong>{option.label}</strong>
                  <small>{option.description}</small>
                </span>
                <span className="creation-picker-check">
                  {option.value === value && <Icon name="check" size={15} />}
                </span>
              </button>
            ))}
          </div>,
          document.body,
        )}
    </>
  );
}
