import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

test('Studio uses one accessible rem scale for text, chrome and content', async () => {
  const css = await readFile(new URL('../src/style.css', import.meta.url), 'utf8');
  const controls = await readFile(new URL('../src/ui/controls.jsx', import.meta.url), 'utf8');
  assert.match(css, /font-size: 101\.5625%/); // 13px × 1.25 at the default 16px preference
  for (const [selector, property, value] of [
    ['.rail', 'width', '4.46154rem'],
    ['.home-hero', 'max-width', '56.92308rem'],
    ['.button', 'height', '2.53846rem'],
  ]) assert.ok(css.includes(`${property}: ${value}`), `${selector} scales with the root`);
  assert.match(controls, /width=\{`\$\{size \/ 13\}rem`\}/);
  assert.doesNotMatch(css, /\bzoom\s*:/);
});
