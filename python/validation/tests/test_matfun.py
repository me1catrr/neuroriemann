"""Validación cruzada de las funciones matriciales de NeuroRiemann.jl.

Referencias independientes:
- SciPy: ``expm`` (Padé + escalado y cuadrado), ``logm`` (Schur inverso
  escalado y cuadrado), ``sqrtm`` (Schur), ``fractional_matrix_power``;
- pyRiemann: ``pyriemann.utils.base`` (vía eigh), si está instalado.
"""

import numpy as np
import pytest
import scipy.linalg as sl

from neuroriemann_val import RTOL, load_fixture, rel_err

DATA = load_fixture("matfun_spd.json")
CASES = DATA["cases"]
IDS = [c["id"] for c in CASES]


def test_metadata():
    assert DATA["seed"] == 20261103
    assert len(CASES) >= 5


@pytest.mark.parametrize("case", CASES, ids=IDS)
def test_inputs_are_valid(case):
    P, S = case["P"], case["S"]
    assert np.array_equal(P, P.T) and np.array_equal(S, S.T)
    assert np.linalg.eigvalsh(P).min() > 0


@pytest.mark.parametrize("case", CASES, ids=IDS)
def test_scipy(case):
    P, S = case["P"], case["S"]
    assert rel_err(case["expm_S"], sl.expm(S)) < RTOL
    assert rel_err(case["logm_P"], np.real(sl.logm(P))) < RTOL
    assert rel_err(case["sqrtm_P"], np.real(sl.sqrtm(P))) < RTOL
    assert rel_err(case["invsqrtm_P"], np.linalg.inv(np.real(sl.sqrtm(P)))) < RTOL
    assert rel_err(case["powm_P_0.3"], np.real(sl.fractional_matrix_power(P, 0.3))) < RTOL


@pytest.mark.parametrize("case", CASES, ids=IDS)
def test_outputs_symmetric(case):
    for key in ("expm_S", "logm_P", "sqrtm_P", "invsqrtm_P", "powm_P_0.3"):
        A = case[key]
        assert np.array_equal(A, A.T), key


@pytest.mark.parametrize("case", CASES, ids=IDS)
def test_pyriemann(case):
    base = pytest.importorskip("pyriemann.utils.base")
    P, S = case["P"], case["S"]
    assert rel_err(case["expm_S"], base.expm(S)) < RTOL
    assert rel_err(case["logm_P"], base.logm(P)) < RTOL
    assert rel_err(case["sqrtm_P"], base.sqrtm(P)) < RTOL
    assert rel_err(case["invsqrtm_P"], base.invsqrtm(P)) < RTOL
    assert rel_err(case["powm_P_0.3"], base.powm(P, 0.3)) < RTOL
