// Column-major matrices, left-handed camera, WebGPU 0...1 clip depth: same as AdaEngine.
export const add = (a, b) => a.map((v, i) => v + b[i]);
export const sub = (a, b) => a.map((v, i) => v - b[i]);
export const mul = (a, s) => a.map((v) => v * s);
export const dot = (a, b) => a.reduce((s, v, i) => s + v * b[i], 0);
export const cross = (a, b) => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];
export const length = (a) => Math.hypot(...a);
export const norm = (a) => mul(a, 1 / (length(a) || 1));
export const axis = (i) => [0, 1, 2].map((n) => +(n === i));
export const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
export const snap = (n, step) => (step > 0 ? Math.round(n / step) * step : n);
export const identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
export const vector = (m, v, w = 1) =>
  [0, 1, 2, 3].map(
    (r) => m[r] * v[0] + m[4 + r] * v[1] + m[8 + r] * v[2] + m[12 + r] * w,
  );
export const point = (m, v) => {
  const p = vector(m, v);
  return mul(p.slice(0, 3), 1 / p[3]);
};
export const direction = (m, v) => vector(m, v, 0).slice(0, 3);
export function multiply(a, b) {
  return b.flatMap((_, i) =>
    i % 4 ? [] : vector(a, b.slice(i, i + 3), b[i + 3]),
  );
}
export function inverse(m) {
  const rows = [0, 1, 2, 3].map((r) => [
    m[r],
    m[4 + r],
    m[8 + r],
    m[12 + r],
    ...axis4(r),
  ]);
  for (let c = 0; c < 4; c++) {
    let p = c;
    for (let r = c + 1; r < 4; r++)
      if (Math.abs(rows[r][c]) > Math.abs(rows[p][c])) p = r;
    if (Math.abs(rows[p][c]) < 1e-12) return null;
    [rows[p], rows[c]] = [rows[c], rows[p]];
    const d = rows[c][c];
    rows[c] = rows[c].map((v) => v / d);
    for (let r = 0; r < 4; r++)
      if (r !== c) {
        const s = rows[r][c];
        rows[r] = rows[r].map((v, i) => v - s * rows[c][i]);
      }
  }
  return [0, 1, 2, 3].flatMap((c) => rows.map((row) => row[c + 4]));
}
const axis4 = (i) => [0, 1, 2, 3].map((n) => +(n === i));
export const quatMul = (a, b) => [
  a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1],
  a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
  a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3],
  a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2],
];
export const quatAxis = (a, angle) => [
  ...mul(norm(a), Math.sin(angle / 2)),
  Math.cos(angle / 2),
];
export const quatInverse = (q) => [-q[0], -q[1], -q[2], q[3]];
export const rotate = (q, v) =>
  quatMul(quatMul(q, [...v, 0]), quatInverse(q)).slice(0, 3);
export function quaternion(m) {
  const r = [0, 4, 8].map((c) => norm(m.slice(c, c + 3))),
    trace = r[0][0] + r[1][1] + r[2][2];
  let q;
  if (trace > 0) {
    const s = Math.sqrt(trace + 1) * 2;
    q = [
      (r[1][2] - r[2][1]) / s,
      (r[2][0] - r[0][2]) / s,
      (r[0][1] - r[1][0]) / s,
      s / 4,
    ];
  } else {
    let i = 0;
    if (r[1][1] > r[i][i]) i = 1;
    if (r[2][2] > r[i][i]) i = 2;
    const j = (i + 1) % 3,
      k = (i + 2) % 3,
      s = Math.sqrt(1 + r[i][i] - r[j][j] - r[k][k]) * 2;
    q = [0, 0, 0, 0];
    q[i] = s / 4;
    q[j] = (r[i][j] + r[j][i]) / s;
    q[k] = (r[i][k] + r[k][i]) / s;
    q[3] = (r[j][k] - r[k][j]) / s;
  }
  return norm(q);
}
export function project(v, vp, size) {
  const p = vector(vp, v);
  if (p[3] <= 1e-6) return null;
  return [
    ((p[0] / p[3] + 1) * size[0]) / 2,
    ((1 - p[1] / p[3]) * size[1]) / 2,
    p[2] / p[3],
  ];
}
export function ray(p, invVP, size) {
  const xy = [(p[0] / size[0]) * 2 - 1, 1 - (p[1] / size[1]) * 2];
  const near = point(invVP, [...xy, 0]),
    far = point(invVP, [...xy, 0.999]);
  return { origin: near, direction: norm(sub(far, near)) };
}
export function intersectBox(r, m, low, high) {
  const inv = inverse(m);
  if (!inv) return null;
  const o = point(inv, r.origin),
    d = direction(inv, r.direction);
  let near = -Infinity,
    far = Infinity;
  for (let i = 0; i < 3; i++) {
    if (Math.abs(d[i]) < 1e-9) {
      if (o[i] < low[i] || o[i] > high[i]) return null;
      continue;
    }
    const a = (low[i] - o[i]) / d[i],
      b = (high[i] - o[i]) / d[i];
    near = Math.max(near, Math.min(a, b));
    far = Math.min(far, Math.max(a, b));
    if (near > far) return null;
  }
  return far >= 0 ? Math.max(0, near) : null;
}
export function planePoint(r, origin, normal) {
  const d = dot(r.direction, normal);
  if (Math.abs(d) < 1e-6) return null;
  return add(
    r.origin,
    mul(r.direction, dot(sub(origin, r.origin), normal) / d),
  );
}
export function axisParameter(r, origin, a) {
  const offset = sub(r.origin, origin),
    b = dot(r.direction, a),
    denom = 1 - b * b;
  return Math.abs(denom) > 1e-5
    ? (dot(offset, a) - b * dot(offset, r.direction)) / denom
    : null;
}
export function boxCorners(entity) {
  return [0, 1, 2, 3, 4, 5, 6, 7].map((i) =>
    point(
      entity.matrix,
      [0, 1, 2].map((a) => (i & (1 << a) ? entity.max[a] : entity.min[a])),
    ),
  );
}
export function worldUnitsPerPixel(origin, vp, invVP, size) {
  const screen = project(origin, vp, size);
  if (!screen) return null;
  const a = point(invVP, [
    (screen[0] / size[0]) * 2 - 1,
    1 - (screen[1] / size[1]) * 2,
    screen[2],
  ]);
  const b = point(invVP, [
    ((screen[0] + 1) / size[0]) * 2 - 1,
    1 - (screen[1] / size[1]) * 2,
    screen[2],
  ]);
  return length(sub(a, b));
}

// A drag starts from one captured frame and a local transform. Parent inverses
// preserve the authored coordinate space, including rotated/scaled ancestors.
export function translateLocal(start, worldDelta, parent) {
  const inv = inverse(parent);
  if (!inv)
    throw new Error("Нельзя переместить объект: масштаб родителя равен нулю");
  return {
    ...start,
    position: add(start.position, direction(inv, worldDelta)),
  };
}
export function rotateLocal(start, localAxis, angle) {
  return {
    ...start,
    rotation: norm(quatMul(start.rotation, quatAxis(localAxis, angle))),
  };
}
