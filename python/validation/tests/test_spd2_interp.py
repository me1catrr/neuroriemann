"""Validación cruzada de geodésicas y distancias E, LE y AI en SPD(2).

Referencias independientes: fórmulas directas con SciPy y las funciones de
pyRiemann (``pyriemann.utils.geodesic`` y ``pyriemann.utils.distance``).
"""

import numpy as np
import pytest
import scipy.linalg as sl

from neuroriemann_val import RTOL, load_fixture, rel_err

DATA = load_fixture("spd2_interp.json")
CASES = DATA["cases"]
IDS = [c["id"] for c in CASES]
METRICS = ("E", "LE", "AI")


def spd2(l1, l2, theta):
    c, s = np.cos(theta), np.sin(theta)
    R = np.array([[c, -s], [s, c]])
    return R @ np.diag([l1, l2]) @ R.T


def _sym(M):
    return (M + M.T) / 2


def geodesic_scipy(metric, A, B, t):
    if metric == "E":
        return (1 - t) * A + t * B
    if metric == "LE":
        return sl.expm((1 - t) * np.real(sl.logm(A)) + t * np.real(sl.logm(B)))
    Ah = np.real(sl.sqrtm(A))
    Aih = np.linalg.inv(Ah)
    C = _sym(Aih @ B @ Aih)
    return Ah @ np.real(sl.fractional_matrix_power(C, t)) @ Ah


def distance_scipy(metric, A, B):
    if metric == "E":
        return np.linalg.norm(A - B)
    if metric == "LE":
        return np.linalg.norm(np.real(sl.logm(A)) - np.real(sl.logm(B)))
    lam = sl.eigh(B, A, eigvals_only=True)
    return np.sqrt(np.sum(np.log(lam) ** 2))


@pytest.mark.parametrize("case", CASES, ids=IDS)
def test_parametrizacion(case):
    assert rel_err(case["A"], spd2(*case["A_params"])) < RTOL
    assert rel_err(case["B"], spd2(*case["B_params"])) < RTOL


@pytest.mark.parametrize("metric", METRICS)
@pytest.mark.parametrize("case", CASES, ids=IDS)
def test_scipy(case, metric):
    A, B = case["A"], case["B"]
    assert abs(case[f"d_{metric}"] - distance_scipy(metric, A, B)) <= RTOL * max(case[f"d_{metric}"], 1)
    for k, t in enumerate(case["t"]):
        assert rel_err(case[f"gamma_{metric}"][k], geodesic_scipy(metric, A, B, t)) < RTOL


@pytest.mark.parametrize("case", CASES, ids=IDS)
def test_geomean_riccati(case):
    A, B, X = case["A"], case["B"], case["geomean"]
    assert rel_err(X @ np.linalg.solve(A, X), B) < 1e-9
    assert rel_err(X, case["gamma_AI"][2]) < RTOL  # t = 1/2


@pytest.mark.parametrize("case", CASES, ids=IDS)
def test_pyriemann(case):
    geo = pytest.importorskip("pyriemann.utils.geodesic")
    dist = pytest.importorskip("pyriemann.utils.distance")
    A, B = case["A"], case["B"]
    fun_geo = {"E": geo.geodesic_euclid, "LE": geo.geodesic_logeuclid, "AI": geo.geodesic_riemann}
    fun_dist = {"E": dist.distance_euclid, "LE": dist.distance_logeuclid, "AI": dist.distance_riemann}
    for m in METRICS:
        d = float(fun_dist[m](A, B))
        assert abs(case[f"d_{m}"] - d) <= RTOL * max(d, 1), m
        for k, t in enumerate(case["t"]):
            assert rel_err(case[f"gamma_{m}"][k], fun_geo[m](A, B, t)) < RTOL, (m, t)
