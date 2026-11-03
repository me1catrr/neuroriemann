# Métricas sobre SPD(n): distancias y geodésicas (capítulo «Métricas sobre SPD»).
#
# Convenciones (sin factores constantes adicionales):
#   d_E(A, B)  = ‖A − B‖_F
#   d_LE(A, B) = ‖log A − log B‖_F
#   d_AI(A, B) = ‖log(A^{-1/2} B A^{-1/2})‖_F = (Σ log² λᵢ(A⁻¹B))^{1/2}
#
#   γ_E(t)  = (1 − t) A + t B
#   γ_LE(t) = exp((1 − t) log A + t log B)
#   γ_AI(t) = A^{1/2} (A^{-1/2} B A^{-1/2})^t A^{1/2}

"""
    SPDMetric

Supertipo de las geometrías sobre ``\\SPD_n``: [`Euclidean`](@ref),
[`LogEuclidean`](@ref) y [`AffineInvariant`](@ref).
"""
abstract type SPDMetric end

"Métrica euclídea (de Frobenius) heredada de ``\\Sym_n``. No es completa en ``\\SPD_n``."
struct Euclidean <: SPDMetric end

"Métrica log-euclídea: imagen recíproca de la euclídea por ``\\Logm``. Es plana."
struct LogEuclidean <: SPDMetric end

"Métrica afín-invariante (de Fisher–Rao salvo factor constante). Curvatura no positiva."
struct AffineInvariant <: SPDMetric end

_checkspd(P) = isspd(P) || throw(DomainError(P, "se requiere una matriz SPD"))

function _checkpair(A, B)
    size(A) == size(B) || throw(DimensionMismatch("A y B deben tener el mismo tamaño"))
    _checkspd(A)
    _checkspd(B)
end

"""
    distance(metric, A, B)

Distancia geodésica entre `A, B ∈ SPD(n)` para la métrica indicada.

Para `AffineInvariant` se usa la forma espectral
``\\dAI(A,B) = (\\sum_i \\log^2 λ_i)^{1/2}`` con ``λ_i`` los autovalores del
problema generalizado simétrico ``Bv = λAv``, equivalente a
``\\|\\Logm(A^{-1/2}BA^{-1/2})\\|_F`` y numéricamente preferible.
"""
function distance(::Euclidean, A::AbstractMatrix{<:Real}, B::AbstractMatrix{<:Real})
    _checkpair(A, B)
    return norm(A - B)
end

function distance(::LogEuclidean, A::AbstractMatrix{<:Real}, B::AbstractMatrix{<:Real})
    _checkpair(A, B)
    return norm(logm(A) - logm(B))
end

function distance(::AffineInvariant, A::AbstractMatrix{<:Real}, B::AbstractMatrix{<:Real})
    _checkpair(A, B)
    λ = eigvals(symmetrize(B), symmetrize(A))
    return sqrt(sum(abs2 ∘ log, λ))
end

"""
    interpolate(metric, A, B, t)

Punto ``γ(t)`` de la geodésica de la métrica indicada con ``γ(0) = A`` y
``γ(1) = B``. Para ``t ∉ [0, 1]`` se extrapola a lo largo de la misma geodésica;
en la euclídea el resultado puede dejar de ser SPD (no es completa).
"""
function interpolate(::Euclidean, A::AbstractMatrix{<:Real}, B::AbstractMatrix{<:Real}, t::Real)
    _checkpair(A, B)
    return symmetrize((1 - t) * A + t * B)
end

function interpolate(::LogEuclidean, A::AbstractMatrix{<:Real}, B::AbstractMatrix{<:Real}, t::Real)
    _checkpair(A, B)
    return expm((1 - t) * logm(A) + t * logm(B))
end

function interpolate(::AffineInvariant, A::AbstractMatrix{<:Real}, B::AbstractMatrix{<:Real}, t::Real)
    _checkpair(A, B)
    Ah, Aih = sqrtm(A), invsqrtm(A)
    C = symmetrize(Aih * B * Aih)
    return symmetrize(Ah * powm(C, t) * Ah)
end

"""
    geomean(A, B)

Media geométrica ``A \\# B = γ_{AI}(1/2)``: única solución SPD de la ecuación
de Riccati ``X A^{-1} X = B``.
"""
geomean(A::AbstractMatrix{<:Real}, B::AbstractMatrix{<:Real}) = interpolate(AffineInvariant(), A, B, 1 // 2)

"""
    ellipse(P; npts = 200)

Puntos (matriz `2 × npts`) de la elipse ``\\{x : x^\\top P^{-1} x = 1\\}`` asociada
a ``P ∈ \\SPD_2``: semiejes ``\\sqrt{λ_i}`` en las direcciones de los
autovectores. Es la imagen del círculo unidad por ``P^{1/2}``.
"""
function ellipse(P::AbstractMatrix{<:Real}; npts::Integer = 200)
    size(P) == (2, 2) || throw(DimensionMismatch("ellipse requiere una matriz 2 × 2"))
    θ = range(0, 2π; length = npts)
    return Matrix(sqrtm(P)) * vcat(cos.(θ)', sin.(θ)')
end

"""
    spd2(λ1, λ2, θ)

Matriz de ``\\SPD_2`` con autovalores `λ1, λ2 > 0` y primer autovector
``(\\cos θ, \\sin θ)``: ``R_θ \\diag(λ_1, λ_2) R_θ^\\top``.
"""
function spd2(λ1::Real, λ2::Real, θ::Real)
    (λ1 > 0 && λ2 > 0) || throw(DomainError((λ1, λ2), "los autovalores deben ser positivos"))
    c, s = cos(θ), sin(θ)
    R = [c -s; s c]
    return symmetrize(R * Diagonal([λ1, λ2]) * R')
end
