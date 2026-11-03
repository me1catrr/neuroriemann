using NeuroRiemann
using LinearAlgebra
using StableRNGs
using Test

"Matriz SPD aleatoria bien condicionada: X Xᵀ / n + I."
randspd(rng, n) = (X = randn(rng, n, n); Symmetric(X * X' / n + I))

"Matriz ortogonal aleatoria (factor Q de una QR con signos normalizados)."
function randorth(rng, n)
    F = qr(randn(rng, n, n))
    return Matrix(F.Q) * Diagonal(sign.(diag(F.R)))
end

const RTOL = 1e-12

@testset "NeuroRiemann" begin
    rng = StableRNG(20261103)

    @testset "isspd" begin
        @test isspd([2.0 1.0; 1.0 2.0])
        @test !isspd([1.0 2.0; 2.0 1.0])            # autovalores 3 y −1
        @test !isspd([1.0 1.0; 0.0 1.0])            # no simétrica
        @test !isspd(zeros(3, 3))
        @test !isspd([1.0 0.0; 0.0 NaN])
        @test isspd(randspd(rng, 6))
    end

    @testset "covarianza con referencia promedio: rango ≤ n − 1" begin
        n, T = 8, 2000
        X = randn(rng, n, T)
        Xavg = X .- sum(X; dims = 1) ./ n           # referencia promedio
        C = Xavg * Xavg' / (T - 1)
        @test norm(C * ones(n)) <= 1e-10 * norm(C)  # 𝟏 ∈ ker C
        @test rank(C) == n - 1
        @test !isspd(C)
        @test_throws DomainError logm(C)
        @test isspd(X * X' / (T - 1))               # sin rereferenciar: SPD
    end

    @testset "concordancia con LinearAlgebra (n = $n)" for n in (1, 2, 3, 5, 16)
        P = randspd(rng, n)
        S = Symmetric(randn(rng, n, n))
        @test expm(S) ≈ exp(S) rtol = RTOL
        @test logm(P) ≈ log(P) rtol = RTOL
        @test sqrtm(P) ≈ sqrt(P) rtol = RTOL
        @test powm(P, 0.3) ≈ P^0.3 rtol = 1e-10
    end

    @testset "identidades (n = $n)" for n in (2, 3, 8)
        P = randspd(rng, n)
        S = Symmetric(randn(rng, n, n))
        @test expm(logm(P)) ≈ P rtol = RTOL
        @test logm(expm(S)) ≈ S rtol = 1e-10
        @test sqrtm(P) * sqrtm(P) ≈ P rtol = RTOL
        @test invsqrtm(P) * P * invsqrtm(P) ≈ I rtol = RTOL
        @test powm(P, 0.5) ≈ sqrtm(P) rtol = RTOL
        @test powm(P, -0.5) ≈ invsqrtm(P) rtol = RTOL
        @test powm(P, 0.3) * powm(P, 0.7) ≈ P rtol = RTOL
        @test logm(powm(P, 2.5)) ≈ 2.5 * logm(P) rtol = RTOL
        @test tr(logm(P)) ≈ logdet(P) rtol = RTOL
        # equivariancia ortogonal: f(Q P Qᵀ) = Q f(P) Qᵀ
        Q = randorth(rng, n)
        @test logm(Symmetric(Q * P * Q')) ≈ Q * logm(P) * Q' rtol = 1e-10
        # el resultado es exactamente simétrico
        @test logm(P) isa Symmetric
        @test issymmetric(Matrix(expm(S)))
    end

    @testset "casos degenerados" begin
        D = Diagonal([1e-5, 1.0, 1e5])                # κ = 10¹⁰: aceptada
        @test logm(Matrix(D)) ≈ Diagonal(log.(diag(D))) rtol = RTOL
        Dbad = Matrix(Diagonal([1e-8, 1.0, 1e8]))     # κ = 10¹⁶: numéricamente singular
        @test !isspd(Dbad)
        @test isspd(Dbad; rtol = 0)
        @test_throws DomainError logm(Dbad)
        @test logm(Matrix(1.0I, 4, 4)) == zeros(4, 4)
        @test expm(zeros(3, 3)) ≈ I
        @test_throws DomainError logm([1.0 2.0; 2.0 1.0])
        @test_throws DomainError expm([0.0 1.0; 0.0 0.0])
        @test_throws DimensionMismatch expm(zeros(2, 3))
    end

    # Apéndice D, @prp-tib-frobenius: ‖log(A⁻¹B)‖_F ≥ (Σ log² λᵢ)^{1/2},
    # con igualdad si y solo si A y B conmutan.
    @testset "Proposición D.1 (norma de Frobenius de log(A⁻¹B))" begin
        for n in (2, 4, 6)
            A, B = randspd(rng, n), randspd(rng, n)
            spectral = sqrt(sum(abs2, log.(eigvals(B, A))))
            frob = norm(log(A \ B))
            @test frob > spectral * (1 + 1e-6)          # no conmutan: desigualdad estricta
            Q = randorth(rng, n)
            Ac = Symmetric(Q * Diagonal(1 .+ rand(rng, n)) * Q')
            Bc = Symmetric(Q * Diagonal(1 .+ rand(rng, n)) * Q')  # conmutan con Ac
            @test norm(real(log(Ac \ Bc))) ≈ sqrt(sum(abs2, log.(eigvals(Bc, Ac)))) rtol = 1e-10
        end
    end
end
