// spd2.js — Geometría de SPD(2) en forma cerrada para los simuladores OJS.
//
// Módulo ES sin dependencias. Las matrices se representan como [[a, b], [b, c]].
// Es una traducción mínima de NeuroRiemann.jl (fuente de verdad) restringida a
// 2 × 2, validada contra fixtures/spd2_interp.json con `node --test`.
//
// Para S = [[a, b], [b, c]] simétrica: λ± = m ± r, con m = (a + c)/2,
// r = hypot((a − c)/2, b), y autovector de λ+ igual a (cos φ, sin φ),
// φ = ½·atan2(2b, a − c). Entonces f(S) = f(λ+) v vᵀ + f(λ−) (I − v vᵀ).

/** Descomposición espectral de una simétrica 2 × 2. */
export function eig2(S) {
  const a = S[0][0], b = S[0][1], c = S[1][1];
  const m = (a + c) / 2;
  const r = Math.hypot((a - c) / 2, b);
  const phi = 0.5 * Math.atan2(2 * b, a - c);
  // Sin cancelación: el autovalor de mayor módulo es m + sign(m)·r; el otro,
  // det/(ese autovalor), pues λ+ λ− = det. Evita perder dígitos en m − r si λ+ ≫ λ−.
  const det = a * c - b * b;
  let l1, l2;
  if (m >= 0) {
    l1 = m + r;
    l2 = l1 !== 0 ? det / l1 : 0;
  } else {
    l2 = m - r;
    l1 = det / l2;
  }
  return { values: [l1, l2], angle: phi, vector: [Math.cos(phi), Math.sin(phi)] };
}

/** Función matricial espectral f(S). */
export function fun(S, f) {
  const { values: [l1, l2], vector: [x, y] } = eig2(S);
  const f1 = f(l1), f2 = f(l2);
  // f1 v vᵀ + f2 (I − v vᵀ) = f2 I + (f1 − f2) v vᵀ
  const d = f1 - f2;
  return [[f2 + d * x * x, d * x * y], [d * x * y, f2 + d * y * y]];
}

export const add = (A, B) => [[A[0][0] + B[0][0], A[0][1] + B[0][1]], [A[1][0] + B[1][0], A[1][1] + B[1][1]]];
export const scale = (s, A) => [[s * A[0][0], s * A[0][1]], [s * A[1][0], s * A[1][1]]];
export const mul = (A, B) => [
  [A[0][0] * B[0][0] + A[0][1] * B[1][0], A[0][0] * B[0][1] + A[0][1] * B[1][1]],
  [A[1][0] * B[0][0] + A[1][1] * B[1][0], A[1][0] * B[0][1] + A[1][1] * B[1][1]],
];
export const sym = (A) => {
  const o = (A[0][1] + A[1][0]) / 2;
  return [[A[0][0], o], [o, A[1][1]]];
};
export const det = (A) => A[0][0] * A[1][1] - A[0][1] * A[1][0];
export const trace = (A) => A[0][0] + A[1][1];
export const frob = (A) => Math.hypot(A[0][0], A[0][1], A[1][0], A[1][1]);

export const expm = (S) => fun(S, Math.exp);
export const logm = (P) => fun(P, Math.log);
export const sqrtm = (P) => fun(P, Math.sqrt);
export const invsqrtm = (P) => fun(P, (l) => 1 / Math.sqrt(l));
export const powm = (P, t) => fun(P, (l) => Math.pow(l, t));

/** R(θ) diag(λ1, λ2) R(θ)ᵀ. */
export function spd2(l1, l2, theta) {
  const c = Math.cos(theta), s = Math.sin(theta);
  const d = l1 - l2;
  return [[l2 + d * c * c, d * c * s], [d * c * s, l2 + d * s * s]];
}

/** Geodésica γ(t) de la métrica "E", "LE" o "AI" con γ(0) = A, γ(1) = B. */
export function interpolate(metric, A, B, t) {
  switch (metric) {
    case "E":
      return add(scale(1 - t, A), scale(t, B));
    case "LE":
      return expm(add(scale(1 - t, logm(A)), scale(t, logm(B))));
    case "AI": {
      const Ah = sqrtm(A), Aih = invsqrtm(A);
      const C = sym(mul(mul(Aih, B), Aih));
      return sym(mul(mul(Ah, powm(C, t)), Ah));
    }
    default:
      throw new Error(`métrica desconocida: ${metric}`);
  }
}

/** Distancia geodésica de la métrica "E", "LE" o "AI". */
export function distance(metric, A, B) {
  switch (metric) {
    case "E":
      return frob(add(A, scale(-1, B)));
    case "LE":
      return frob(add(logm(A), scale(-1, logm(B))));
    case "AI": {
      const Aih = invsqrtm(A);
      const { values } = eig2(sym(mul(mul(Aih, B), Aih)));
      return Math.hypot(Math.log(values[0]), Math.log(values[1]));
    }
    default:
      throw new Error(`métrica desconocida: ${metric}`);
  }
}

/** Media geométrica A # B = γ_AI(1/2). */
export const geomean = (A, B) => interpolate("AI", A, B, 0.5);

/** Puntos {x, y} de la elipse {x : xᵀ P⁻¹ x = 1} (imagen del círculo por P^{1/2}). */
export function ellipse(P, n = 120) {
  const R = sqrtm(P);
  return Array.from({ length: n + 1 }, (_, k) => {
    const th = (2 * Math.PI * k) / n;
    const u = Math.cos(th), v = Math.sin(th);
    return { x: R[0][0] * u + R[0][1] * v, y: R[1][0] * u + R[1][1] * v };
  });
}

/** Resumen geométrico de P: autovalores, anisotropía λ+/λ−, ángulo principal (rad, en (−π/2, π/2]). */
export function summary(P) {
  const { values: [l1, l2], angle } = eig2(P);
  return { l1, l2, det: det(P), trace: trace(P), anisotropy: l1 / l2, angle };
}
