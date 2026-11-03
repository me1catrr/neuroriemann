# Funciones matriciales espectrales sobre Sym(n) y SPD(n).
#
# Para S simétrica con descomposición espectral S = U diag(λ) Uᵀ (U ortogonal),
# f(S) := U diag(f(λ)) Uᵀ. Está bien definida (no depende de la elección de U)
# porque f actúa por igual sobre cada autoespacio.

"""
    symmetrize(A)

Parte simétrica `(A + Aᵀ)/2`, devuelta como `Symmetric`.
"""
symmetrize(A::AbstractMatrix{<:Real}) = Symmetric((A + A') / 2)

"""
    isspd(A; rtol = 1e-12)

Devuelve `true` si `A` es **numéricamente** simétrica y definida positiva.

La simetría se exige con tolerancia `sqrt(eps)` relativa a `‖A‖_F`. La
definición positiva se decide por el menor autovalor de la parte simétrica:
`λ_min > rtol · λ_max`, es decir, número de condición espectral `< 1/rtol`.
Con el valor por defecto se aceptan matrices mal condicionadas hasta `κ ≈ 10¹²`
y se rechazan las numéricamente singulares, como una covarianza EEG con
referencia promedio (rango ≤ n − 1, `λ_min/λ_max ~ 10⁻¹⁶`). Con `rtol = 0` se
comprueba solo `λ_min > 0`, que no es fiable por debajo de `eps · λ_max`.
"""
function isspd(A::AbstractMatrix{<:Real}; rtol::Real = 1e-12)
    n, m = size(A)
    n == m || return false
    n == 0 && return false
    all(isfinite, A) || return false
    nA = norm(A)
    nA > 0 || return false
    norm(A - A') <= sqrt(eps(Float64)) * nA || return false
    λ = eigvals(symmetrize(A))
    return first(λ) > rtol * last(λ)
end

"""
    spdfun(f, S; domain = :sym)

Función matricial espectral `U diag(f.(λ)) Uᵀ` de la matriz simétrica `S`.

Con `domain = :spd` se exige que `S` sea SPD (para `log`, raíces y potencias
reales) y se lanza `DomainError` en caso contrario.
"""
function spdfun(f, S::AbstractMatrix{<:Real}; domain::Symbol = :sym)
    size(S, 1) == size(S, 2) || throw(DimensionMismatch("la matriz debe ser cuadrada"))
    if domain === :spd
        isspd(S) || throw(DomainError(S, "se requiere una matriz SPD"))
    elseif domain === :sym
        norm(S - S') <= sqrt(eps(Float64)) * max(norm(S), 1) ||
            throw(DomainError(S, "se requiere una matriz simétrica"))
    else
        throw(ArgumentError("domain debe ser :sym o :spd"))
    end
    F = eigen(symmetrize(S))
    return Symmetric(F.vectors * Diagonal(f.(F.values)) * F.vectors')
end

"""
    expm(S)

Exponencial matricial ``\\Expm(S)`` de una matriz simétrica. El resultado es SPD.
"""
expm(S::AbstractMatrix{<:Real}) = spdfun(exp, S; domain = :sym)

"""
    logm(P)

Logaritmo matricial principal ``\\Logm(P)`` de una matriz SPD. Es la inversa de
[`expm`](@ref) como biyección ``\\Sym_n → \\SPD_n``.
"""
logm(P::AbstractMatrix{<:Real}) = spdfun(log, P; domain = :spd)

"""
    sqrtm(P)

Raíz cuadrada principal ``P^{1/2}`` de una matriz SPD (la única raíz SPD).
"""
sqrtm(P::AbstractMatrix{<:Real}) = spdfun(sqrt, P; domain = :spd)

"""
    invsqrtm(P)

``P^{-1/2}``, inversa de la raíz cuadrada principal de una matriz SPD.
"""
invsqrtm(P::AbstractMatrix{<:Real}) = spdfun(λ -> inv(sqrt(λ)), P; domain = :spd)

"""
    powm(P, t)

Potencia real principal ``P^t = \\Expm(t \\Logm P)`` de una matriz SPD.
"""
powm(P::AbstractMatrix{<:Real}, t::Real) = spdfun(λ -> λ^t, P; domain = :spd)
