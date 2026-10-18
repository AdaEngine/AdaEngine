import test from "node:test";
import assert from "node:assert/strict";
import * as M from "../../../Plugins/AdaWebExportPlugin/Runtime/studio-editor-math.js";

const near = (a, b, eps = 1e-6) =>
  a.forEach((v, i) => assert.ok(Math.abs(v - b[i]) < eps, `${a} != ${b}`));
test("camera projection round trip uses the actual WebGPU depth interval", () => {
  const projection = [
    1,
    0,
    0,
    0,
    0,
    2,
    0,
    0,
    0,
    0,
    100 / 99.9,
    1,
    0,
    0,
    -10 / 99.9,
    0,
  ];
  const camera = [...M.identity];
  camera[12] = 3;
  camera[13] = 4;
  camera[14] = -10;
  const vp = M.multiply(projection, M.inverse(camera)),
    point = [4, 3, 2],
    size = [1000, 600],
    screen = M.project(point, vp, size);
  const r = M.ray(screen, M.inverse(vp), size);
  near(
    M.add(
      r.origin,
      M.mul(r.direction, M.dot(M.sub(point, r.origin), r.direction)),
    ),
    point,
  );
  assert.ok(screen[2] > 0 && screen[2] < 1);
});
test("movement preserves rotated and nonuniformly scaled parent coordinates", () => {
  const parent = [0, 2, 0, 0, -3, 0, 0, 0, 0, 0, 4, 0, 10, 20, 30, 1];
  const start = {
      position: [1, 2, 3],
      rotation: [0, 0, 0, 1],
      scale: [1, 1, 1],
    },
    delta = [5, -2, 8];
  const next = M.translateLocal(start, delta, parent);
  near(
    M.sub(M.point(parent, next.position), M.point(parent, start.position)),
    delta,
  );
  assert.deepEqual(start.position, [1, 2, 3]);
  assert.throws(
    () => M.translateLocal(start, delta, Array(16).fill(0)),
    /родителя/,
  );
});
test("picking compares world ray distances without normalizing each local ray", () => {
  const r = { origin: [0, 0, -10], direction: [0, 0, 1] },
    a = [...M.identity],
    b = [...M.identity];
  a[10] = 0.1;
  b[10] = 10;
  b[14] = 8;
  assert.equal(M.intersectBox(r, a, [-1, -1, -1], [1, 1, 1]), 9.9);
  assert.equal(M.intersectBox(r, b, [-1, -1, -1], [1, 1, 1]), 8);
  assert.equal(M.intersectBox(r, M.identity, [3, 3, 3], [4, 4, 4]), null);
});
test("axis drag and plane intersection are stable for orthographic and perspective rays", () => {
  const r = { origin: [3, 4, -10], direction: [0, 0, 1] };
  assert.equal(M.axisParameter(r, [0, 0, 0], [1, 0, 0]), 3);
  assert.equal(M.axisParameter(r, [0, 0, 0], [0, 0, 1]), null);
  near(M.planePoint(r, [0, 0, 0], [0, 0, 1]), [3, 4, 0]);
  assert.equal(M.planePoint(r, [0, 0, 0], [0, 1, 0]), null);
});
test("local rotation composes with the existing orientation and stays normalized", () => {
  const q = M.quatAxis([0, 1, 0], Math.PI / 2),
    start = { position: [0, 0, 0], rotation: q, scale: [1, 2, 3] };
  const next = M.rotateLocal(start, [0, 0, 1], Math.PI / 2);
  near(M.rotate(next.rotation, [1, 0, 0]), [0, 1, 0]);
  assert.equal(M.length(next.rotation), 1);
  const matrix = [
    ...M.rotate(q, [1, 0, 0]),
    0,
    ...M.rotate(q, [0, 1, 0]),
    0,
    ...M.rotate(q, [0, 0, 1]),
    0,
    0,
    0,
    0,
    1,
  ];
  near(M.quaternion(matrix), q);
  assert.equal(M.snap(0.74, 0.5), 0.5);
});
