using YasolSolver
using Test
using JuMP
using MathOptInterface
const MOI = MathOptInterface

@testset "YasolSolver.jl" begin
    include("MOI_wrapper.jl")
end
