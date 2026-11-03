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

jvec(v) = "[" * join(jnum.(v), ", ") * "]"

const METRIC_KEYS = (("E", Euclidean()), ("LE", LogEuclidean()), ("AI", AffineInvariant()))
const TGRID = (0.0, 0.25, 0.5, 0.75, 1.0)

# Casos de SPD(2) parametrizados por (λ1, λ2, θ) para A y B, como en el simulador.
const SPD2_CASES = (
    ("generico", (3.0, 0.5, 0.3), (1.2, 0.8, 1.9)),
    ("rotacion_pura", (4.0, 0.25, 0.0), (4.0, 0.25, π / 2)),
    ("conmutan", (2.0, 0.5, 0.7), (0.6, 3.0, 0.7)),
    ("mal_condicionado", (1e3, 1e-3, 0.2), (2.0, 0.5, 1.1)),
    ("isotropo_anisotropo", (1.0, 1.0, 0.0), (5.0, 0.2, -0.6)),
    ("anisotropo_no_conmutan", (4.0, 0.2, 0.0), (2.0, 0.4, 1.2)),   # laboratorio del capítulo
)

function spd2_interp_cases()
    cases = String[]
    for (id, pa, pb) in SPD2_CASES
        A, B = spd2(pa...), spd2(pb...)
        fields = [
            "\"id\": $(jstr(id))",
            "\"A_params\": $(jvec(pa))",
            "\"B_params\": $(jvec(pb))",
            "\"A\": $(jmat(A))",
            "\"B\": $(jmat(B))",
            "\"t\": $(jvec(TGRID))",
        ]
        for (k, m) in METRIC_KEYS
            push!(fields, "\"d_$k\": $(jnum(distance(m, A, B)))")
            push!(fields, "\"gamma_$k\": [" * join((jmat(interpolate(m, A, B, t)) for t in TGRID), ", ") * "]")
        end
        push!(fields, "\"geomean\": $(jmat(geomean(A, B)))")
        push!(cases, "    {\n      " * join(fields, ",\n      ") * "\n    }")
    end
    return cases
end

function write_spd2_interp()
    body = """
    {
      "description": "Geodésicas y distancias E, LE y AI en SPD(2) calculadas por NeuroRiemann.jl",
      "generator": "julia/scripts/generate_fixtures.jl",
      "julia_version": $(jstr(string(VERSION))),
      "neuroriemann_version": $(jstr(string(pkgversion(NeuroRiemann)))),
      "conventions": "A = R(θ) diag(λ1, λ2) R(θ)ᵀ con parámetros [λ1, λ2, θ]; d_E = ‖A−B‖_F; d_LE = ‖log A − log B‖_F; d_AI = ‖log(A^{-1/2} B A^{-1/2})‖_F; gamma_X[k] = γ_X(t[k])",
      "cases": [
    $(join(spd2_interp_cases(), ",\n"))
      ]
    }
    """
    path = joinpath(OUTDIR, "spd2_interp.json")
    write(path, body)
    println("Escrito ", relpath(path, ROOT))
end

function main()
    mkpath(OUTDIR)
    write_spd2_interp()
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
