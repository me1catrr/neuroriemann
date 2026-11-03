"""Validación cruzada de NeuroRiemann.jl.

Este paquete **no** produce resultados del libro: lee los fixtures generados por
Julia (``fixtures/*.json``) y los recalcula con implementaciones independientes
(NumPy/SciPy, pyRiemann) con tolerancia declarada.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np

REPO_ROOT = Path(__file__).resolve().parents[3]
FIXTURES = REPO_ROOT / "fixtures"

#: Tolerancia relativa de la validación cruzada (véase el apéndice B).
RTOL = 1e-10


def load_fixture(name: str) -> dict:
    """Carga ``fixtures/<name>`` y convierte las matrices a ``numpy.ndarray``."""
    with open(FIXTURES / name, encoding="utf-8") as fh:
        data = json.load(fh)
    for case in data.get("cases", []):
        for key, value in case.items():
            if isinstance(value, list):
                case[key] = np.asarray(value, dtype=float)
    return data


def rel_err(a: np.ndarray, b: np.ndarray) -> float:
    """Error relativo en norma de Frobenius ``‖a − b‖_F / max(‖b‖_F, 1)``."""
    return float(np.linalg.norm(a - b) / max(np.linalg.norm(b), 1.0))
