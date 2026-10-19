import { test } from 'node:test';
import assert from 'node:assert/strict';
import { playgroundRoute, safeContinuation } from '../src/routes.js';
test('old entry points normalize without losing auth callback state', () => {
  for (const [from, to] of [['/', '/games'], ['/studio/', '/games'], ['/games/create', '/create'], ['/cloud/projects', '/publications'], ['/cloud/projects/new', '/publications/new']])
    assert.equal(playgroundRoute(from).path, to);
  assert.equal(playgroundRoute('/cloud?code=exchange&desktop=request').href, '/account?code=exchange&desktop=request');
});
test('public and private project identities have distinct routes', () => {
  assert.equal(playgroundRoute('/projects/private-1').view, 'editor');
  assert.equal(playgroundRoute('/publications/page-1').view, 'publications');
  assert.equal(playgroundRoute('/games/game-1').id, 'game-1');
  for (const path of ['/v1/me', '/store', '/console', '/studio/studio.js', '/projects/a%2Fb']) assert.equal(playgroundRoute(path), null);
});
test('sign-in destinations cannot escape Playground or replay auth parameters', () => {
  for (const value of ['https://evil.test/', '//evil.test/games', '/\\evil.test', '/games/../account', '/games?a=b', '/account', '/legal/terms', '/games/%2fexample']) assert.equal(safeContinuation(value), null);
  assert.equal(safeContinuation('/games/create'), '/create');
  assert.equal(safeContinuation('/projects/work-1'), '/projects/work-1');
});
