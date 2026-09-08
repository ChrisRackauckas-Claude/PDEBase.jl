using PDEBase
using ModelingToolkit
using ModelingToolkitBase: get_tspan
using SciMLBase
using Symbolics
using Test

struct TspanDiscretization <: PDEBase.AbstractEquationSystemDiscretization
    time::Any
end
struct TspanSpace <: PDEBase.AbstractDiscreteSpace
    discvars::Any
end
struct TspanMetadata <: SciMLBase.AbstractDiscretizationMetadata{true}
    pdesys::Any
end

PDEBase.get_time(disc::TspanDiscretization) = disc.time
PDEBase.get_discvars(s::TspanSpace) = s.discvars

@testset "Discretized system carries the time span" begin
    @parameters t x
    @variables u(..)
    Dt = Differential(t)
    Dx = Differential(x)
    pdesys = PDESystem(
        [Dt(u(t, x)) ~ Dx(Dx(u(t, x)))],
        [u(0, x) ~ 0, u(t, 0) ~ 0, u(t, 1) ~ 0],
        [t ∈ (0, 1), x ∈ (0, 1)],
        [t, x],
        [u(t, x)];
        name = :pdebase_tspan_test
    )

    @variables w1(t) w2(t)
    space = TspanSpace(Dict(:u => [w1, w2]))
    state = PDEBase.EquationState([Dt(w1) ~ -w1, Dt(w2) ~ w1 - w2], Equation[])

    sys, tspan = PDEBase.generate_system(
        state, space, [], (0.0, 2.5), TspanMetadata(pdesys), TspanDiscretization(t)
    )
    @test tspan == (0.0, 2.5)
    @test get_tspan(sys) == (0.0, 2.5)
    # the span has to survive compilation, which is where a problem is built from
    @test ODEProblem(mtkcompile(sys), [w1 => 1.0, w2 => 0.0]).tspan == (0.0, 2.5)

    @variables z1 z2
    nlstate = PDEBase.EquationState([z1 ~ 1.0, z2 ~ z1 + 1.0], Equation[])
    nlspace = TspanSpace(Dict(:u => [z1, z2]))
    nlsys, nltspan = PDEBase.generate_system(
        nlstate, nlspace, [], nothing, TspanMetadata(pdesys), TspanDiscretization(nothing)
    )
    @test nltspan === nothing
    @test get_tspan(nlsys) === nothing
end
