# Ada DocC Theme

The documentation shares Ada's editorial visual system: solid graphite surfaces, thin gray separators, square controls, bold sans-serif headings, monospace metadata, and blue links and focus indicators. DocC's Dark and automatic dark appearances match the website; its Light choice uses a coherent light monochrome palette. Syntax colors remain distinct in both appearances.

The DocC archive is themed after generation so the source documentation stays compatible with standard DocC tooling. The docs workflow applies this command before search preparation and deployment:

```sh
node scripts/apply-docc-theme.mjs docs
```

The command copies `theme.css` and `theme.js` into the archive and injects them into every generated HTML entry point. It is idempotent and preserves an optional DocC hosting base path. CSS covers API references, articles, navigation and filter controls, declarations, code and tables, plus tutorial overviews, chapters, steps, code previews, assessments, and next-tutorial surfaces. DocC retains its routing, search, responsive navigation, appearance selector, and semantic alert/status colors.

AdaScript code fences use the Markdown language identifier `ada`. DocC keeps this as `data-syntax="ada"`; the unchanged theme runtime adds keyword, annotation, type, string, number, punctuation, and nested-comment highlighting after initial load and client-side navigation.

For visual verification without compiling Swift, use a temporary local copy or GET-only proxy of the deployed documentation and substitute the source theme assets at `/css/adaengine-theme.css` and `/js/adaengine-docc-theme.js`. Check a module, an article, a symbol declaration, search/filter navigation, a tutorial overview and a tutorial step at desktop and mobile widths, including Light and Dark. A proxy checks the current deployed DocC renderer; a newly generated archive still needs its own verification when the renderer changes.
