// Validación de spd2.js contra fixtures/spd2_interp.json (generado por Julia).
// Ejecutar desde la raíz:  node --test simulators/
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import * as G from "./spd2.js";

const RTOL = 1e-10;
const data = JSON.parse(readFileSync(new URL("../../fixtures/spd2_interp.json", import.meta.url), "utf8"));

const diff = (A, B) => G.frob(G.add(A, G.scale(-1, B)));
const relErr = (A, B) => diff(A, B) / Math.max(G.frob(B), 1);

for (const c of data.cases) {
  test(`spd2(λ1, λ2, θ) reproduce A y B — ${c.id}`, () => {
    assert.ok(relErr(G.spd2(...c.A_params), c.A) < RTOL);
    assert.ok(relErr(G.spd2(...c.B_params), c.B) < RTOL);
  });

  for (const m of ["E", "LE", "AI"]) {
    test(`distancia y geodésica ${m} — ${c.id}`, () => {
      const d = G.distance(m, c.A, c.B);
      assert.ok(Math.abs(d - c[`d_${m}`]) <= RTOL * Math.max(d, 1), `d_${m}: ${d} vs ${c[`d_${m}`]}`);
      c.t.forEach((t, k) => {
        const e = relErr(G.interpolate(m, c.A, c.B, t), c[`gamma_${m}`][k]);
        assert.ok(e < RTOL, `γ_${m}(${t}): error relativo ${e}`);
      });
    });
  }

  test(`media geométrica — ${c.id}`, () => {
    assert.ok(relErr(G.geomean(c.A, c.B), c.geomean) < RTOL);
  });
}

// Entradas exactas: aquí m − r pierde todos los dígitos de λ− y det/λ+ no.
// (Con una matriz rotada de κ = 10¹², el redondeo de las propias entradas,
// ~eps·10⁶, ya supera a λ− = 10⁻⁶: no hay valor exacto con que comparar.)
test("eig2: autovalores sin cancelación (κ = 10¹², también indefinida)", () => {
  const [l1, l2] = G.eig2([[1e6, 0], [0, 1e-6]]).values;
  assert.equal(l1, 1e6);
  assert.ok(Math.abs(l2 / 1e-6 - 1) < 1e-15);
  const [s1, s2] = G.eig2([[-1e3, 0], [0, 1e-3]]).values; // indefinida, dominante negativo
  assert.ok(Math.abs(s1 / 1e-3 - 1) < 1e-15);
  assert.equal(s2, -1e3);
});

test("ellipse: puntos sobre xᵀ P⁻¹ x = 1", () => {
  const P = G.spd2(4, 1, Math.PI / 6);
  const iP = G.fun(P, (l) => 1 / l);
  for (const { x, y } of G.ellipse(P, 32)) {
    const q = x * (iP[0][0] * x + iP[0][1] * y) + y * (iP[1][0] * x + iP[1][1] * y);
    assert.ok(Math.abs(q - 1) < 1e-12);
  }
});
