# Tests del capítulo «Métricas sobre SPD». Se incluye desde runtests.jl
# (usa randspd, randorth, RTOL y el generador `rng` de allí).

const METRICS = (Euclidean(), LogEuclidean(), AffineInvariant())
const TS = (0.0, 0.1, 0.25, 0.5, 0.8, 1.0)

@testset "métricas sobre SPD" begin
    rng = StableRNG(6)

    @testset "extremos y simetría de la geodésica ($(nameof(typeof(m))))" for m in METRICS
        for n in (2, 3, 6)
            A, B = randspd(rng, n), randspd(rng, n)
            @test interpolate(m, A, B, 0) ≈ A rtol = RTOL
            @test interpolate(m, A, B, 1) ≈ B rtol = RTOL
            @test interpolate(m, A, B, 0.3) ≈ interpolate(m, B, A, 0.7) rtol = 1e-10
            @test all(isspd(interpolate(m, A, B, t)) for t in TS)
        end
    end

    @testset "axiomas de distancia ($(nameof(typeof(m))))" for m in METRICS
        A, B, C = randspd(rng, 4), randspd(rng, 4), randspd(rng, 4)
        @test distance(m, A, A) ≈ 0 atol = 1e-12
        @test distance(m, A, B) ≈ distance(m, B, A) rtol = 1e-12
        @test distance(m, A, C) <= distance(m, A, B) + distance(m, B, C) + 1e-12
        @test distance(m, A, B) > 0
    end

    @testset "velocidad constante: d(γ(s), γ(t)) = |t − s| d(A, B) ($(nameof(typeof(m))))" for m in METRICS
        A, B = randspd(rng, 5), randspd(rng, 5)
        d = distance(m, A, B)
        for (s, t) in ((0.0, 0.5), (0.2, 0.9), (0.3, 0.35))
            γs, γt = interpolate(m, A, B, s), interpolate(m, A, B, t)
            @test distance(m, γs, γt) ≈ abs(t - s) * d rtol = 1e-10
        end
    end

    @testset "dAI: forma espectral = ‖log(A^{-1/2} B A^{-1/2})‖_F" begin
        for n in (2, 4, 7)
            A, B = randspd(rng, n), randspd(rng, n)
            Aih = invsqrtm(A)
            @test distance(AffineInvariant(), A, B) ≈ norm(logm(symmetrize(Aih * B * Aih))) rtol = 1e-12
            @test distance(AffineInvariant(), A, B) ≈ distance(AffineInvariant(), inv(A), inv(B)) rtol = 1e-10
            @test distance(AffineInvariant(), Matrix(1.0I, n, n), B) ≈ norm(logm(B)) rtol = 1e-12
        end
    end

    @testset "determinante: det γ_LE(t) = det γ_AI(t) = det(A)^{1−t} det(B)^t" begin
        for n in (2, 3, 6), t in TS
            A, B = randspd(rng, n), randspd(rng, n)
            target = det(A)^(1 - t) * det(B)^t
            @test det(interpolate(LogEuclidean(), A, B, t)) ≈ target rtol = 1e-10
            @test det(interpolate(AffineInvariant(), A, B, t)) ≈ target rtol = 1e-10
        end
    end

    @testset "hinchamiento euclídeo: det γ_E(t) ≥ det(A)^{1−t} det(B)^t" begin
        for n in (2, 3, 6), t in (0.1, 0.5, 0.9)
            A, B = randspd(rng, n), randspd(rng, n)
            @test det(interpolate(Euclidean(), A, B, t)) > det(A)^(1 - t) * det(B)^t
        end
        # rotación pura: mismos autovalores, el determinante euclídeo crece estrictamente
        A = spd2(4.0, 0.25, 0.0)
        B = spd2(4.0, 0.25, π / 2)
        @test det(interpolate(Euclidean(), A, B, 0.5)) ≈ (4.25 / 2)^2 rtol = 1e-12
        @test det(interpolate(AffineInvariant(), A, B, 0.5)) ≈ 1.0 rtol = 1e-12
        @test det(interpolate(LogEuclidean(), A, B, 0.5)) ≈ 1.0 rtol = 1e-12
    end

    @testset "potencia total: γ_AI ⪯ γ_E y tr γ_LE, tr γ_AI ≤ tr γ_E (@prp-traza)" begin
        for n in (2, 3, 6), t in (0.1, 0.5, 0.9)
            A, B = randspd(rng, n), randspd(rng, n)
            E, L, G = (interpolate(m, A, B, t) for m in METRICS)
            @test minimum(eigvals(Symmetric(E - G))) >= -1e-12 * norm(E)   # orden de Loewner
            @test tr(G) <= tr(E) + 1e-12
            @test tr(L) <= tr(E) + 1e-12
            @test tr(E) ≈ (1 - t) * tr(A) + t * tr(B) rtol = 1e-12
        end
    end

    @testset "matrices que conmutan: γ_LE = γ_AI y d_LE = d_AI" begin
        for n in (2, 5)
            Q = randorth(rng, n)
            A = Symmetric(Q * Diagonal(0.5 .+ 2rand(rng, n)) * Q')
            B = Symmetric(Q * Diagonal(0.5 .+ 2rand(rng, n)) * Q')
            for t in TS
                @test interpolate(LogEuclidean(), A, B, t) ≈ interpolate(AffineInvariant(), A, B, t) rtol = 1e-10
            end
            @test distance(LogEuclidean(), A, B) ≈ distance(AffineInvariant(), A, B) rtol = 1e-10
        end
        # sin conmutar, en general difieren
        A, B = randspd(rng, 3), randspd(rng, 3)
        @test !isapprox(interpolate(LogEuclidean(), A, B, 0.5), interpolate(AffineInvariant(), A, B, 0.5); rtol = 1e-6)
    end

    @testset "media geométrica A # B" begin
        for n in (2, 4, 6)
            A, B = randspd(rng, n), randspd(rng, n)
            X = geomean(A, B)
            @test X * inv(A) * X ≈ B rtol = 1e-10          # ecuación de Riccati
            @test geomean(B, A) ≈ X rtol = 1e-10            # simetría
            @test distance(AffineInvariant(), A, X) ≈ distance(AffineInvariant(), X, B) rtol = 1e-10
            @test geomean(A, A) ≈ A rtol = RTOL
        end
        # escalares: media geométrica usual
        @test geomean(fill(4.0, 1, 1), fill(9.0, 1, 1))[1] ≈ 6.0 rtol = RTOL
    end

    @testset "invariancias" begin
        for n in (2, 4)
            A, B = randspd(rng, n), randspd(rng, n)
            W = randn(rng, n, n) + 3I                       # W ∈ GL(n) (genérica)
            Q = randorth(rng, n)
            cg(M) = symmetrize(W * M * W')
            og(M) = symmetrize(Q * M * Q')
            # AI: invariante por congruencia con cualquier W ∈ GL(n)
            @test distance(AffineInvariant(), cg(A), cg(B)) ≈ distance(AffineInvariant(), A, B) rtol = 1e-10
            for t in (0.25, 0.6)
                @test interpolate(AffineInvariant(), cg(A), cg(B), t) ≈ cg(interpolate(AffineInvariant(), A, B, t)) rtol = 1e-9
            end
            # LE: invariante por similitud ortogonal y por escala común, no por congruencia general
            @test distance(LogEuclidean(), og(A), og(B)) ≈ distance(LogEuclidean(), A, B) rtol = 1e-10
            @test distance(LogEuclidean(), 3A, 3B) ≈ distance(LogEuclidean(), A, B) rtol = 1e-10
            @test !isapprox(distance(LogEuclidean(), cg(A), cg(B)), distance(LogEuclidean(), A, B); rtol = 1e-4)
            # E: invariante por similitud ortogonal; escala lineal
            @test distance(Euclidean(), og(A), og(B)) ≈ distance(Euclidean(), A, B) rtol = 1e-10
            @test distance(Euclidean(), 3A, 3B) ≈ 3distance(Euclidean(), A, B) rtol = 1e-12
        end
    end

    @testset "spd2 y ellipse" begin
        P = spd2(4.0, 1.0, π / 6)
        @test eigvals(P) ≈ [1.0, 4.0] rtol = RTOL
        @test P * [cos(π / 6), sin(π / 6)] ≈ 4 * [cos(π / 6), sin(π / 6)] rtol = RTOL
        E = ellipse(P; npts = 64)
        @test size(E) == (2, 64)
        @test all(x -> isapprox(dot(x, P \ x), 1; rtol = 1e-12), eachcol(E))
        @test_throws DomainError spd2(1.0, 0.0, 0.0)
        @test_throws DimensionMismatch ellipse(Matrix(1.0I, 3, 3))
    end

    @testset "errores de dominio" begin
        A = randspd(rng, 3)
        @test_throws DomainError distance(AffineInvariant(), A, [1.0 0 0; 0 1 0; 0 0 0])
        @test_throws DimensionMismatch distance(LogEuclidean(), A, Matrix(1.0I, 2, 2))
    end
end
