"""
    NeuroRiemann

Paquete de referencia del libro *NeuroRiemann*: geometría riemanniana de
matrices simétricas definidas positivas (SPD) y aplicaciones al EEG.

Convenciones (véase el apéndice de notación):

- `expm`, `logm`, `sqrtm`, `powm` son funciones **matriciales** espectrales
  (``\\Expm``, ``\\Logm``), no las aplicaciones riemannianas ``\\Exp_P``, ``\\Log_P``.
- La raíz cuadrada y el logaritmo son siempre los **principales**.
- Todas las funciones devuelven `Symmetric`, de modo que la simetría es exacta
  y no solo aproximada en aritmética de coma flotante.
"""
module NeuroRiemann

using LinearAlgebra

export symmetrize, isspd, spdfun, expm, logm, sqrtm, invsqrtm, powm

include("matfun.jl")

end # module
