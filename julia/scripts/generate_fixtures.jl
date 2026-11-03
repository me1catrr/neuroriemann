# Genera fixtures/*.json para la validación cruzada (Python, JS).
#
# Uso (desde la raíz del repositorio):
#   julia --project=. julia/scripts/generate_fixtures.jl
#
# Solo biblioteca estándar + StableRNGs: el JSON se escribe a mano. Los números
# se imprimen con `repr`, que en Julia es la representación decimal más corta
# que reproduce exactamente el Float64 (ida y vuelta sin pérdida).

using NeuroRiemann
using LinearAlgebra
using StableRNGs

const SEED = 20261103
const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const OUTDIR = joinpath(ROOT, "fixtures")

jnum(x::Real) = isfinite(x) ? repr(Float64(x)) : error("valor no finito en fixture")
jmat(A::AbstractMatrix) = "[" * join(("[" * join(jnum.(A[i, :]), ", ") * "]" for i in axes(A, 1)), ", ") * "]"
jstr(s::AbstractString) = "\"" * escape_string(s) * "\""

randspd(rng, n) = (X = randn(rng, n, n); Symmetric(X * X' / n + I))

function matfun_cases(rng)
    cases = String[]
    for (k, n) in enumerate((2, 2, 3, 5, 8))
        P = randspd(rng, n)
        S = Symmetric(randn(rng, n, n))
        fields = [
            "\"id\": $(jstr("spd$(n)_$(k)"))",
            "\"n\": $n",
            "\"P\": $(jmat(P))",
            "\"S\": $(jmat(S))",
            "\"expm_S\": $(jmat(expm(S)))",
            "\"logm_P\": $(jmat(logm(P)))",
            "\"sqrtm_P\": $(jmat(sqrtm(P)))",
            "\"invsqrtm_P\": $(jmat(invsqrtm(P)))",
            "\"powm_P_0.3\": $(jmat(powm(P, 0.3)))",
        ]
        push!(cases, "    {\n      " * join(fields, ",\n      ") * "\n    }")
    end
    return cases
end

function main()
    mkpath(OUTDIR)
    rng = StableRNG(SEED)
    body = """
    {
      "description": "Funciones matriciales espectrales sobre Sym(n)/SPD(n) calculadas por NeuroRiemann.jl",
      "generator": "julia/scripts/generate_fixtures.jl",
      "seed": $SEED,
      "julia_version": $(jstr(string(VERSION))),
      "neuroriemann_version": $(jstr(string(pkgversion(NeuroRiemann)))),
      "conventions": "logaritmo y raíz principales; resultados simétricos exactos",
      "cases": [
    $(join(matfun_cases(rng), ",\n"))
      ]
    }
    """
    path = joinpath(OUTDIR, "matfun_spd.json")
    write(path, body)
    println("Escrito ", relpath(path, ROOT))
end

main()
