# Playground tag artwork

These original transparent PNG sheets were generated for the approved Playground
prototype with ImageGen. Each sheet contains a central icon and four themed props.
The files are copied unchanged; `src/playground-tag-art.json` stores crop rectangles
used by CSS backgrounds, rather than rewriting the images. Hover and keyboard
focus reveal the props behind the capsule; reduced motion keeps them hidden.

`npm run build` copies this directory to `dist/playground`. The Studio frontend
export includes the directory recursively, alongside `studio.js` and `studio.css`.

`mascot-guide-v1.png` is copied byte for byte from the pointing-pose asset in
`Documentation/Brand/Assets/PlaygroundMascot`. Create and My projects reuse the
canonical mascot described in `Documentation/Brand/PlaygroundMascot.md`.

`mascot-builder-v1.png` is the Create-page variation generated with the built-in
ImageGen tool from `mascot-guide-v1.png`: the same robot assembles a small grassy
platformer level with a tree and a collectible star. Transparent alpha is kept.
The guide pose remains on My projects. Prompt: `mascot-builder-v1.prompt.txt`.
