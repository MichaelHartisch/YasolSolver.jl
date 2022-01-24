module TestMOIWrapper

using Test
using YasolSolver
using JuMP
using MathOptInterface
const MOI = MathOptInterface

function runtests()
    for name in names(@__MODULE__; all = true)
        if !startswith("$(name)", "test_")
            continue
        end
        @testset "$(name)" begin
            getfield(@__MODULE__, name)()
        end
    end
end

function test_rawOptimizerAttributes()
    model = Model(() -> YasolSolver.Optimizer("C:/Yasol/Yasol_CLP"))

    set_optimizer_attribute(model, "time limit", 60)
    set_optimizer_attribute(model, "output info", 1)
    set_optimizer_attribute(model, "problem file name", "FullTest.qlp")

    @test get_optimizer_attribute(model, "time limit") == 60
    @test get_optimizer_attribute(model, "output info") == 1
    @test get_optimizer_attribute(model, "problem file name") == "FullTest.qlp"
end

function test_solverName()
    model = Model(() -> YasolSolver.Optimizer("C:/Yasol/Yasol_CLP"))
    @test MOI.get(model, MOI.SolverName()) == "YASOL"
end

function test_numberOfVariables()
    model = Model(() -> YasolSolver.Optimizer("C:/Yasol/Yasol_CLP"))
    @test MOI.get(model, MOI.NumberOfVariables()) == 0
    @variable(model, x1, integer=true, lower_bound=0, upper_bound=2)
    @test MOI.get(model, MOI.NumberOfVariables()) == 1
    @variable(model, x2, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="all", block=2)
    @test MOI.get(model, MOI.NumberOfVariables()) == 2
end

function test_OptSense()
    model = Model(() -> YasolSolver.Optimizer("C:/Yasol/Yasol_CLP"))
    @variable(model, x1, integer=true, lower_bound=0, upper_bound=2)
    @variable(model, x2, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="all", block=2)
    @constraint(model, con1, x1 + x2 <= 10)
    @objective(model, Max, x1+2x2)
    @test MOI.get(model, MOI.ObjectiveSense()) == MAX_SENSE
end

function test_OptFunctionType()
    model = Model(() -> YasolSolver.Optimizer("C:/Yasol/Yasol_CLP"))
    @variable(model, x1, integer=true, lower_bound=0, upper_bound=2)
    @variable(model, x2, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="all", block=2)
    @constraint(model, con1, x1 + x2 <= 10)
    @objective(model, Max, x1+2x2)
    @test MOI.get(model, MOI.ObjectiveFunctionType()) == MathOptInterface.ScalarAffineFunction{Float64}
end

function test_variableAttributes()
    model = Model(() -> YasolSolver.Optimizer("C:/Yasol/Yasol_CLP"))
    @variable(model, x1, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="all", block=2)
    @test MOI.get(model, YasolSolver.VariableAttribute("quantifier"), x1) == "all"
    @test MOI.get(model, YasolSolver.VariableAttribute("block"), x1) == 2
    @variable(model, x2, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="exists", block=1)
    @test MOI.get(model, YasolSolver.VariableAttribute("quantifier"), x2) == "exists"
    @test MOI.get(model, YasolSolver.VariableAttribute("block"), x2) == 1
end

function test_constraintAttributes()
    model = Model(() -> YasolSolver.Optimizer("C:/Yasol/Yasol_CLP"))
    @variable(model, x1, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="all", block=2)
    @variable(model, x2, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="exists", block=1)
    @constraint(model, con1, -1*x1 +2*x2<=10, YasolConstraint, quantifier="all")
    @constraint(model, con2, -1*x1 +2*x2<=20, YasolConstraint, quantifier="exists")
    @test MOI.get(model, YasolSolver.ConstraintAttribute("quantifier"), con1) == "all"
    @test MOI.get(model, YasolSolver.ConstraintAttribute("quantifier"), con2) == "exists"
end

function test_status()
    model = Model(() -> YasolSolver.Optimizer("C:/Yasol/Yasol_CLP"))
    @test MOI.get(model, MOI.TerminationStatus()) == OPTIMIZE_NOT_CALLED
end

function test_status()
    model = Model(() -> YasolSolver.Optimizer("C:/Yasol/Yasol_CLP"))
    @test MOI.get(model, MOI.TerminationStatus()) == OPTIMIZE_NOT_CALLED
end

end

TestMOIWrapper.runtests()


"""
For local testing

# change yasol initial parameter
yasol.setInitialParameter("C:/Yasol", "writeOutputFile", 1)
# get initial parameter
@show yasol.getInitialParameter("C:/Yasol")


MAXIMIZE
1x1 +1x2 +1x3
SUBJECT TO
-2x2 -1x3 <= -2
-1x1 +2x2 +1x3 <= 2
2x1 + 4x2 <= 6
BOUNDS
0 <= x1 <= 2
0 <= x2 <= 1
0 <= x3 <= 2
GENERAL
x1
BINARY
x2
EXISTS
x1 x3
ALL
x2
ORDER
x1 x2 x3
END

# define model
cd("C:/Yasol")

model = Model(() -> yasol.Optimizer("C:/Yasol/Yasol_CLP"))

set_optimizer_attribute(model, "time limit", 60)
set_optimizer_attribute(model, "output info", 1)
set_optimizer_attribute(model, "problem file name", "Test08122021.qlp")

@variable(model, x1, integer=true, lower_bound=0, upper_bound=2)
MOI.set(model, yasol.VariableAttribute("quantifier"), x1, "exists")
MOI.set(model, yasol.VariableAttribute("block"), x1, 1)

@variable(model, x2, binary=true, lower_bound=0, upper_bound=1)
MOI.set(model, yasol.VariableAttribute("quantifier"), x2, "all")
MOI.set(model, yasol.VariableAttribute("block"), x2, 2)

@variable(model, x3, lower_bound=0, upper_bound=2)
MOI.set(model, yasol.VariableAttribute("quantifier"), x3, "exists")
MOI.set(model, yasol.VariableAttribute("block"), x3, 3)

@constraint(model, con1, -2*x2 -1x3 <= -2)

@constraint(model, con2, -1*x1 +2*x2 +1*x3 <= 2)

@constraint(model, con3, 2x1 + 4x2 <= 6)

@objective(model, Max, 1*x1 +1*x2 +1*x3)

optimize!(model)


# import solution
solution = yasol.importSolution("C:/Yasol/Test08122021.qlp.sol")
@show solution
yasol.printSolution(solution)

@show termination_status(model)

@show value(x1)

@show objective_value(model)

@show solve_time(model)


# access model parameters
print(model.moi_backend.optimizer.model)
print(model.moi_backend.optimizer.model.optimizer.is_objective_set)
print(model.moi_backend.model_cache.optattr.keys)
print(model.moi_backend.model)

MOI.get(model, yasol.VariableAttribute("quantifier"), x1)
MOI.get(model, yasol.VariableAttribute("block"), x1)
MOI.get(model, yasol.ConstraintAttribute("quantifier"), con3)

get_optimizer_attribute(model, "time limit")
get_optimizer_attribute(model, "output info")



# using constraints that have attributes

MINIMIZE
-x1 -2x2 +2x3 +x4
SUBJECT TO
E_Constraint1: x1 -2x2 +x3 -x4 <= 1
E_Constraint2: x1 +x2 +x3 -x4 <= 2
U_Constraint1: x1 +x2 +x3 <= 2
BOUNDS
0 <= x1 <= 1
0 <= x2 <= 1
0 <= x3 <= 1
0 <= x4 <= 1
BINARIES
x1 x2 x3 x4
EXISTS
x1 x2 x4
ALL
x3
ORDER
x1 x2 x3 x4
END

# define model
cd("C:/Yasol")

model = Model(() -> yasol.Optimizer("C:/Yasol/Yasol_CLP"))

set_optimizer_attribute(model, "time limit", 60)
set_optimizer_attribute(model, "output info", 1)
set_optimizer_attribute(model, "problem file name", "ConstraintExt.qlp")

@variable(model, x1, binary=true, lower_bound=0, upper_bound=1)
MOI.set(model, yasol.VariableAttribute("quantifier"), x1, "exists")
MOI.set(model, yasol.VariableAttribute("block"), x1, 1)

@variable(model, x2, binary=true, lower_bound=0, upper_bound=1)
MOI.set(model, yasol.VariableAttribute("quantifier"), x2, "exists")
MOI.set(model, yasol.VariableAttribute("block"), x2, 2)

@variable(model, x3, binary=true, lower_bound=0, upper_bound=1)
MOI.set(model, yasol.VariableAttribute("quantifier"), x3, "all")
MOI.set(model, yasol.VariableAttribute("block"), x3, 3)

@variable(model, x4, binary=true, lower_bound=0, upper_bound=1)
MOI.set(model, yasol.VariableAttribute("quantifier"), x4, "exists")
MOI.set(model, yasol.VariableAttribute("block"), x4, 4)

@constraint(model, con1, 1*x1 -2*x2 +1*x3 -1*x4 <= 1)
MOI.set(model, yasol.ConstraintAttribute("quantifier"), con1, "exists")

@constraint(model, con2, 1*x1 + 1*x2 +1*x3 -1*x4 <= 2)
MOI.set(model, yasol.ConstraintAttribute("quantifier"), con2, "exists")

@constraint(model, con3, 1*x1 + 1*x2 +1*x3 <= 2)
MOI.set(model, yasol.ConstraintAttribute("quantifier"), con3, "all")

@objective(model, Min, -1*x1 -2*x2 +2*x3 +1x4)

optimize!(model)

# import solution
solution = yasol.importSolution("C:/Yasol/ConstraintExt.qlp.sol")
@show solution
yasol.printSolution(solution)

#print(solver_name(model))

#@show model

#print(model)

#write_to_file(model, "model.mps")





# using JuMP extension
cd("C:/Yasol")

model = Model(() -> yasol.Optimizer("C:/Yasol/Yasol_CLP"))

set_optimizer_attribute(model, "time limit", 60)
set_optimizer_attribute(model, "output info", 1)
set_optimizer_attribute(model, "problem file name", "Test2-23_11.qlp")

@variable(model, x1, integer=true, lower_bound=0, upper_bound=2, YasolVariable, quantifier="exists", block=1)

@variable(model, x2, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="all", block=2)

@variable(model, x3, lower_bound=0, upper_bound=2, YasolVariable, quantifier="exists", block=3)

@constraint(model, con1, -2*x2 -1x3 + 8 <= -2 + 2*x2)

@constraint(model, con2, -1*x1 +2*x2 +1*x3 >= -6 + 2*x2, YasolConstraint, quantifier="all")

@constraint(model, con3, 2x1 + 4x2 <= 6)

@objective(model, Max, 1*x1 +1*x2 +1*x3)

optimize!(model)



# import solution
solution = yasol.importSolution("C:/Yasol/Test25112021.qlp.sol")
@show solution
yasol.printSolution(solution)

@show termination_status(model)

@show value(x3)

@show objective_value(model)

@show solve_time(model)


# use full JuMP extension

MINIMIZE
-x1 -2x2 +2x3 +x4
SUBJECT TO
E_Constraint1: x1 -2x2 +x3 -x4 <= 1
E_Constraint2: x1 +x2 +x3 -x4 <= 2
U_Constraint1: x1 +x2 +x3 <= 2
BOUNDS
0 <= x1 <= 1
0 <= x2 <= 1
0 <= x3 <= 1
0 <= x4 <= 1
BINARIES
x1 x2 x3 x4
EXISTS
x1 x2 x4
ALL
x3
ORDER
x1 x2 x3 x4
END

# define model
cd("C:/Yasol")

model = Model(() -> yasol.Optimizer("C:/Yasol/Yasol_CLP"))

set_optimizer_attribute(model, "time limit", 60)
set_optimizer_attribute(model, "output info", 1)
set_optimizer_attribute(model, "problem file name", "ConstraintExt.qlp")

@variable(model, x1, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="exists", block=1)

@variable(model, x2, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="exists", block=2)

@variable(model, x3, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="all", block=3)

@variable(model, x4, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="exists", block=4)

@constraint(model, con1, 1*x1 -2*x2 +1*x3 -1*x4 +5 <= -1*x1 -3, YasolConstraint, quantifier="exists")

@constraint(model, con2, 1*x1 + 1*x2 +1*x3 -1*x4 -2 <= 2 - 2*x2, YasolConstraint, quantifier="exists")

@constraint(model, con3, 1*x1 + 1*x2 +1*x3 <= 1 + x3, YasolConstraint, quantifier="all")

@objective(model, Min, -1*x1 -2*x2 +2*x3 +1x4 - 5)

optimize!(model)

@show termination_status(model)

@show value(x1)

@show objective_value(model)

@show solve_time(model)
"""
