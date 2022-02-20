using YasolSolver
using Test
using JuMP
using MathOptInterface
const MOI = MathOptInterface


@testset "YasolSolver.jl" begin
    #include("MOI_wrapper.jl")

    cd("C:/Yasol")

    model = Model(() -> YasolSolver.Optimizer())

    set_optimizer_attribute(model, "solver path", "C:/Yasol/Yasol_CLP_VersionX")
    set_optimizer_attribute(model, "time limit", 60)
    set_optimizer_attribute(model, "output info", 1)
    set_optimizer_attribute(model, "problem file name", "Test.qlp")

    @variable(model, x1, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="exists", block=1)

    @variable(model, x2, integer=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="exists", block=2)

    @variable(model, x3, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="all", block=3)

    @variable(model, x4, integer=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="exists", block=4)

    @constraint(model, con1, 1*x1 -2*x2 +1*x3 -1*x4 +5 <= -1*x1 -3, YasolConstraint, quantifier="exists")

    @constraint(model, con2, 1*x1 + 1*x2 +1*x3 -1*x4 -2 <= 2 - 2*x2, YasolConstraint, quantifier="exists")

    @constraint(model, con3, 1*x1 + 1*x2 +1*x3 <= 1 + x3, YasolConstraint, quantifier="all")

    @objective(model, Min, -1*x1 -2*x2 +2*x3 +1x4 - 5)

    optimize!(model)
end
