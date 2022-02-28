using Revise
using MathOptInterface
const MOI = MathOptInterface
using JuMP
using DataStructures

### ============================================================================
### Objective expression
### ============================================================================
mutable struct _Objective
    # constant value
    constant::Float64
    # terms
    terms::Vector{MOI.ScalarAffineTerm{Float64}}

    function _Objective(constant::Float64, terms::Vector{MOI.ScalarAffineTerm{Float64}})
        return new(constant, terms)
    end
end

### ============================================================================
### Variables
### ============================================================================
mutable struct _VariableInfo
    # Index of the variable
    index::MOI.VariableIndex
    # The block that the variable appears in.
    block::Int64
    # The quantifier of the variable.
    quantifier::String

    function _VariableInfo(index::MOI.VariableIndex, block::Int64, quantifier::String)
        return new(index, block, quantifier)
    end
end

### ============================================================================
### Variable constraints
### ============================================================================
struct _VariableConstraintInfo
    # Constraint index
    index::MOI.ConstraintIndex
    # Variable Index
    vindex::MOI.VariableIndex
    # Constraint set
    conSet::Any

    function _VariableConstraintInfo(ind::MOI.ConstraintIndex, vind::MOI.VariableIndex, set)
        return new(ind, vind, set)
    end
end

### ============================================================================
### Constraints
### ============================================================================
struct _ConstraintInfo
    # Constraint index
    index::MOI.ConstraintIndex
    # Constraint ScalarAffineFunction
    scalarAffineFunction::MOI.ScalarAffineFunction{Float64}
    # Constraint set
    conSet::Any
    # Constraint quantifier
    quantifier::String

    function _ConstraintInfo(ind::MOI.ConstraintIndex, scalarAffFunc::MOI.ScalarAffineFunction{Float64}, set, quantifier)
        return new(ind, scalarAffFunc, set, quantifier)
    end
end

### ============================================================================
### Results
### ============================================================================
struct _Results
    # status
    #raw_status_string::String
    #termination_status::MOI.TerminationStatusCode

    objective_value::Float64
    runtime::Int64
    #decisionNodes::Int64
    #propagationSteps::Int64
    #learntConstraints::Int64

    # quality
    solutionStatus::String
    gap::Float64

    # variable values
    values::Dict{String, Float64}

    function _Results(obj::Float64, runtime::Int64, solStatus::String, gap::Float64, values::Dict{String, Float64})
        return new(obj, runtime, solStatus, gap, values)
    end
end

"""
    AbstractSolverCommand
An abstract type that allows over-riding the call behavior of the solver.
"""
abstract type AbstractSolverCommand end

"""
    call_solver(
        solver::AbstractSolverCommand,
        qip_filename::String,
        options::Vector{String},
        stdin::IO,
        stdout::IO,
    )::String
Execute the `solver` given the QIP file at `qip_filename`, a vector of `options`,
and `stdin` and `stdout`. Return the filename of the resulting `.sol` file.
"""
function call_solver end

struct _DefaultSolverCommand{F} <: AbstractSolverCommand
    f::F
end

function call_solver(
    solver::_DefaultSolverCommand,
    solverPath::String,
    qip_filename::String,
    options::Vector{Int64},
    stdin::IO,
    stdout::IO,
    output::String,
)
    # parse optimizer attributes, value for time_limit is -1 if not supposed to be set
    cmd =  ``
    if options[2] == -1
        cmd = `$(solverPath) $(qip_filename) $(options[1])`
    else
        cmd = `$(solverPath) $(qip_filename) $(options[1]) $(options[2])`
    end

    solver.f() do solver_path
        ret = run(
            pipeline(
                cmd,
                stdin = stdin,
                stdout = output,
                append=true,
                stderr= output,
            ),
        )
        if ret.exitcode != 0
            error("Nonzero exit code: $(ret.exitcode)")
        end
    end
end


_solver_command(x::String) = _DefaultSolverCommand(f -> f(x))
_solver_command(x::Function) = _DefaultSolverCommand(x)
_solver_command(x::AbstractSolverCommand) = x

### ============================================================================
### Optimizer
### ============================================================================
mutable struct Optimizer <: MOI.AbstractOptimizer
    solver_command::AbstractSolverCommand
    stdin::Any
    stdout::Any
    # result information
    results::_Results
    # solve time
    solve_time::Float64
    # Store MOI.Name().
    name::String
    # The objective expression.
    o::_Objective
    sense::MOI.OptimizationSense
    #is_objective_set::Bool
    # A vector of variable constraints
    vc::Vector{_VariableConstraintInfo}
    # A vector of constraints
    c::Vector{_ConstraintInfo}
    cNumber::Int64
    # A dictionary of info for the variables.
    v::Dict{MOI.VariableIndex,_VariableInfo}
    # was optimizer called
    optimize_not_called::Bool
    # termination status
    termination_status::MOI.TerminationStatusCode

    # solver specific attributes
    # time limit in seconds
    time_limit::Int64
    # output information level
    output_info::Int64
    # problem file name
    problem_file::String
    # name of solver .exe
    solver_path::String
end

"""
    Optimizer(
        solver_command::Union{String,Function},
        stdin::Any = stdin,
        stdout:Any = stdout,
    )
Create a new Optimizer object.

`solver_command`:
* A `String` of the full path of an Yasol executable.

Redirect IO using `stdin` and `stdout`. These arguments are passed to
`Base.pipeline`. See the Julia documentation for more details.
"""
function Optimizer(
        solver_command::Union{AbstractSolverCommand,String,Function} = "",
        stdin::Any = stdin,
        stdout::Any = stdout,
)
    return Optimizer(
        _solver_command(solver_command),
        stdin,
        stdout,
        _Results(
            0.0,
            0,
            "",
            0.0,
            Dict{String,Float64}()
        ),
        NaN,
        "",
        _Objective(0.0, MOI.ScalarAffineTerm{Float64}[]),
        MOI.FEASIBILITY_SENSE,
        _VariableConstraintInfo[],
        _ConstraintInfo[],
        0,
        Dict{MOI.VariableIndex,_VariableInfo}(),
        true,
        MOI.OPTIMIZE_NOT_CALLED,
        -1,
        -1,
        "",
        ""
    )
end

Base.show(io::IO, ::Optimizer) = print(io, "A YASOL model")

MOI.get(model::Optimizer, ::MOI.SolverName) = "YASOL"
MOI.get(model::Optimizer, ::MOI.RawSolver) = model

MOI.supports(::Optimizer, ::MOI.Name) = true
MOI.get(model::Optimizer, ::MOI.Name) = model.name

MOI.get(model::Optimizer, ::MOI.NumberOfVariables) = length(model.v)


function MOI.empty!(model::Optimizer)
    #model.results = _QIPResults()
    model.solve_time = NaN
    model.o = _Objective(0.0, MOI.ScalarAffineTerm{Float64}[])
    model.sense = MOI.FEASIBILITY_SENSE
    model.vc = _VariableConstraintInfo[]
    model.c = _ConstraintInfo[]
    model.cNumber = 0
    model.v = Dict{MOI.VariableIndex,_VariableInfo}()
    model.time_limit = -1
    model.output_info = -1
    model.problem_file = ""
    model.optimize_not_called = true
    return
end

function MOI.is_empty(model::Optimizer)
    if isempty(model.vc) && isempty(model.c) && isempty(model.v)
        return true
    else
        return false
    end
end

# ========================================
#   Supported constraints and objectives
# ========================================
const _SCALAR_FUNCTIONS = Union{
    MOI.VariableIndex,
    MOI.ScalarAffineFunction{Float64},
}

const _SCALAR_SETS = Union{
    MOI.LessThan{Float64},
    MOI.GreaterThan{Float64},
    MOI.EqualTo{Float64},
    MOI.Integer,
    MOI.ZeroOne,
}

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{<:_SCALAR_FUNCTIONS},
    ::Type{<:_SCALAR_SETS},
)
    return true
end

MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{<:MOI.ScalarAffineFunction}) = true

# ========================================
#   Copy_to functionality. No incremental modification supported.
# ========================================
MOI.Utilities.supports_default_copy_to(::Optimizer, ::Bool) = false

function MOI.copy_to(
    dest::Optimizer,
    model::MOI.ModelLike;
    copy_names::Bool = false,
)

    mapping = MOI.Utilities.IndexMap()

    # copy optimizer attributes
    try
        dest.time_limit = MOI.get(model, MOI.RawOptimizerAttribute("time limit"))
    catch
        dest.time_limit = -1
    end

    try
        dest.output_info = MOI.get(model, MOI.RawOptimizerAttribute("output info"))
    catch
        dest.output_info = 1
    end
    try
        dest.problem_file = MOI.get(model, MOI.RawOptimizerAttribute("problem file name"))
    catch
        @error string("Please provide a problem file name! No problem file could be written!")
        return
    end

    # copy objective sense
    dest.sense = MOI.get(model, MOI.ObjectiveSense())

    # copy variables

    # save the quantifier and block of the last variable
    last_block = 0
    last_quantifiers = []
    for v in MOI.get(model, MOI.ListOfVariableIndices())

        try
            quantifier = MOI.get(model, YasolSolver.VariableAttribute("quantifier"), v)
            block = MOI.get(model, YasolSolver.VariableAttribute("block"), v)

            if quantifier !== nothing && block !== nothing
                dest.v[v] = _VariableInfo(v, block, quantifier)

                if block > last_block
                    last_block = block
                end
            else
                @error string("You need to set a quantifier and a block for each variable when using Yasol solver!")
                return
            end

        catch err
            #println("You need to set a quantifier and a block for each variable when using Yasol solver!")
            #@warn string("You need to set a quantifier and a block for each variable when using Yasol solver!")
            @warn string(err)
        end

        mapping[v] = v
    end

    # show warning, if variable in last block is not existential
    for v in MOI.get(model, MOI.ListOfVariableIndices())
        try
            quantifier = MOI.get(model, YasolSolver.VariableAttribute("quantifier"), v)
            block = MOI.get(model, YasolSolver.VariableAttribute("block"), v)

            if block == last_block
                push!(last_quantifiers, quantifier)
            end
        catch err
            @warn string(err)
        end
    end

    for q in last_quantifiers
        if q != "exists"
            @error string("The variable in the last block needs to be existential! Please add a dummy variable!")
            return
        end
    end

    # copy objective function
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    obj = MOI.get(model, MOI.ObjectiveFunction{F}())
    temp = _Objective(obj.constant, obj.terms)
    dest.o = temp

    # copy constraints
    for (F, S) in MOI.get(model, MOI.ListOfConstraintTypesPresent())
        for ci in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
            mapping[ci] = ci

            f = MOI.get(model, MOI.ConstraintFunction(), ci)
            s = MOI.get(model, MOI.ConstraintSet(), ci)

            # get constraint quantifier
            q = ""
            q_temp = MOI.get(model, YasolSolver.ConstraintAttribute("quantifier"), ci)
            if q_temp !== nothing
                q = q_temp
            else
                q = ""
            end

            if typeof(f) == MathOptInterface.VariableIndex
                vcon = _VariableConstraintInfo(ci, f, s)
                push!(dest.vc, vcon)
            else
                con = _ConstraintInfo(ci, f, s, q)
                push!(dest.c, con)
            end
        end
    end

    # count constraints
    values = []
    for con in dest.c
        push!(values, Int64(con.index.value))
    end
    dest.cNumber = length(values)

    return mapping
end

# ========================================
#   Write model to file.
# ========================================
function Base.write(io::IO, qipmodel::Optimizer)

    # print objective sense
    if(qipmodel.sense == MOI.MIN_SENSE)
        println(io, "MINIMIZE")
    elseif qipmodel.sense == MOI.MAX_SENSE
        println(io, "MAXIMIZE")
    end

    # number of variables
    numVar = length(qipmodel.v)
    exist = []
    all = []
    binaries = []
    generals = []

    # print objective function
    for term in qipmodel.o.terms
        # print coefficient and variables
        if term.coefficient < 0.0
            print(io, string(term.coefficient) * "x" * string(term.variable.value) * " ")
        elseif term.coefficient > 0.0
            print(io, "+" * string(term.coefficient) * "x" * string(term.variable.value) * " ")
        end
    end

    # print constant value if != 0
    if qipmodel.o.constant < 0.0
        print(io, string(qipmodel.o.constant))
    else qipmodel.o.constant > 0.0
        print(io, "+ " * string(qipmodel.o.constant))
    end

    println(io, "")

    # print constraints
    println(io, "SUBJECT TO")
    for con in qipmodel.c
        # print quantifier if set
        if con.quantifier !== ""
            if con.quantifier === "exists"
                print(io, "E_Constraint" * string(con.index.value) * ": ")
            elseif con.quantifier === "all"
                print(io, "U_Constraint" * string(con.index.value) * ": ")
            end
        end

        # print terms
        for term in con.scalarAffineFunction.terms
            if term.coefficient < 0.0
                print(io, string(term.coefficient) * "x" * string(term.variable.value) * " ")
            elseif term.coefficient > 0.0
                print(io, "+" * string(term.coefficient) * "x" * string(term.variable.value) * " ")
            end
        end

        temp = 0.0
        temp = temp + (con.scalarAffineFunction.constant)*-1

        """
        # print constant
        if con.scalarAffineFunction.constant < 0.0
            #print(io, string(con.scalarAffineFunction.constant))
            temp+= (con.scalarAffineFunction.constant)*-1
        else con.scalarAffineFunction.constant > 0.0
            #print(io, "+ " * string(con.scalarAffineFunction.constant))
            temp+= (con.scalarAffineFunction.constant)*-1
        end
        """

        # print set
        if typeof(con.conSet) == MathOptInterface.GreaterThan{Float64}
            if temp !== 0.0
                print(io, ">= " * string((con.conSet.lower) + temp))
            else
                print(io, ">= " * string((con.conSet.lower)))
            end
        elseif typeof(con.conSet) == MathOptInterface.LessThan{Float64}
            if temp !== 0.0
                print(io, "<= " * string((con.conSet.upper) + temp))
            else
                print(io, "<= " * string((con.conSet.upper)))
            end
        end
        println(io, "")
    end

    # print variable bounds
    println(io, "BOUNDS")
    for i in 1:numVar
        lower = -9999.9
        upper = 9999.9
        type = nothing
        for varCon in qipmodel.vc
            if varCon.vindex.value == i
                if typeof(varCon.conSet) == MathOptInterface.Integer
                    push!(generals, "x"*string(i))
                    type = "int"
                elseif typeof(varCon.conSet) == MathOptInterface.ZeroOne
                    push!(binaries, "x"*string(i))
                    type = "binary"
                elseif typeof(varCon.conSet) == MathOptInterface.GreaterThan{Float64}
                    lower = varCon.conSet.lower
                elseif typeof(varCon.conSet) == MathOptInterface.LessThan{Float64}
                    upper = varCon.conSet.upper
                end
            end
        end

        # show warning, if variable has no lower or upper bound
        if (lower == -9999.9 || upper == 9999.9)
            @error string("Every variable needs to be bounded from above and below (binary variables as well)!")
            return
        end

        # write bounds
        println(io, string(lower) * " <= " * "x" * string(i) * " <= " * string(upper))
    end

    # check, if all variables are integer or binary
    for a in all
        if !(a in binaries) && (!a in generals)
            @error string("All variables need to be binary or integer!")
            return
        end
    end

    # print binaries
    println(io, "BINARIES")
    bin = ""
    for b in binaries
        bin *= b * " "
    end
    println(io, bin)

    # print generals
    println(io, "GENERALS")
    gen = ""
    for g in generals
        gen *= g * " "
    end
    println(io, gen)

    # print exists
    println(io, "EXISTS")
    exists = ""
    for i in 1:MOI.get(qipmodel, MOI.NumberOfVariables())
        if qipmodel.v[MOI.VariableIndex(i)].quantifier === "exists"
            exists = exists * "x" * string(i) * " "
        end
    end
    println(io, exists)

    # print all
    println(io, "ALL")
    all = ""
    for i in 1:MOI.get(qipmodel, MOI.NumberOfVariables())
        if qipmodel.v[MOI.VariableIndex(i)].quantifier === "all"
            all = all * "x" * string(i) * " "
        end
    end
    println(io, all)

    # print order
    println(io, "ORDER")
    order = ""

    tempDict = OrderedDict{Int64,Int64}()
    for i in 1:MOI.get(qipmodel, MOI.NumberOfVariables())
        tempDict[i] = qipmodel.v[MathOptInterface.VariableIndex(i)].block
    end

    # sort temp dict
    last_block = 0
    last_block_variables = []
    sorted = sort!(tempDict, byvalue=true)

    # build order string
    for (key, value) in sorted
        order = order * "x" * string(key) * " "
        if value > last_block
            last_block = value
        end
    end

    # save all last block variables
    for (key, value) in sorted
        if value == last_block
            push!(last_block_variables, key)
        end
    end

    # make sure, that continuos variables are only allowed in the last block
    for (key, value) in sorted
        if value != last_block
            if !("x"*string(key) in generals) && !("x"*string(key) in binaries)
                @error string("Continuos variables are only allowed in the last block")
                return
            end
        end
    end

    #@warn string(last_block)
    #@warn string(last_block_variables)

    println(io, order)

    println(io, "END")
end

# ========================================
#   Call yasol solver with problem file and parameters.
# ========================================
function MOI.optimize!(model::Optimizer)

    # check if problem file name is set, show warning otherwise
    if(model.problem_file == "")
        @error string("Please provide a problem file name! No problem file could be written!")
        return
    end

    # check if Yasol.ini file is given in the solver folder
    path = joinpath(pwd(), "Yasol.ini")
    if !isfile(String(path))
        @warn string("No Yasol.ini file was found in the solver folder!")
    end

    # check if Yasol .exe is available under given path
    if !isfile(String(model.solver_path*".exe")) && !isfile(String(model.solver_path))
        @error string("No Yasol executable was found under the given path!")
        return
    end

    model.optimize_not_called = false

    options = [model.output_info, model.time_limit]

    start_time = time()
    # create problem file
    qlp_file = joinpath(pwd(), model.problem_file)

    output_file = joinpath(pwd(), (rsplit(model.problem_file, ".")[1]) * "_output.txt")
    touch(output_file)
    open(io -> write(io, model), qlp_file, "w")

    # call solver
    try
        call_solver(
            model.solver_command,
            model.solver_path,
            qlp_file,
            options,
            model.stdin,
            model.stdout,
            output_file,
        )
        # read solution & set results
        model.results = YasolSolver.importSolution(qlp_file * ".sol")

        if model.results.solutionStatus == "OPTIMAL"
            model.termination_status = MOI.OPTIMAL
        end

    catch err
        # TODO show error in results
    end

    model.solve_time = time() - start_time
    return
end

function MOI.write_to_file(model::Optimizer, filename::String)
    open(io -> write(io, model), filename, "w")
    return
end

# ========================================
#   Model attributes
# ========================================
MOI.supports(::Optimizer, ::MOI.RawOptimizerAttribute) = true

function MOI.set(model::Optimizer, param::MOI.RawOptimizerAttribute, value)
    if param == MOI.RawOptimizerAttribute("output info")
        model.output_info = Int64(value)
    elseif param == MOI.RawOptimizerAttribute("time limit")
        model.time_limit = Int64(value)
    elseif param == MOI.RawOptimizerAttribute("problem file name")
        model.problem_file = String(value)
        # check if problem file already exists
        if isfile(String(value))
            @warn "A file with the chosen name already exists. You are about to overwrite that file."
        end
        # check if solution file already exists
        if isfile(String(value) * ".sol")
            @warn "A solution file for the problem already exists. If you create another solution with the same name, you cannot import the new solution using JuMP."
        end
    elseif param == MOI.RawOptimizerAttribute("solver path")
        model.solver_path = String(value)
    end
    return
end

function MOI.get(model::Optimizer, param::MOI.RawOptimizerAttribute)
    if param == MOI.RawOptimizerAttribute("output info")
        return model.output_info
    elseif param == MOI.RawOptimizerAttribute("time limit")
        return model.time_limit
    elseif param == MOI.RawOptimizerAttribute("problem file name")
        return model.problem_file
    elseif param == MOI.RawOptimizerAttribute("solver path")
        return model.solver_path
    end
end

# ========================================
#   Variable attributes
# ========================================
struct VariableAttribute <: MOI.AbstractVariableAttribute
    name::String
end

function MOI.supports(
    model::Optimizer,
    attr::VariableAttribute,
    ::Type{MOI.VariableIndex},
)
    if attr.name === "quantifier" || attr.name === "block"
        return true
    else
        return false
    end
end

function MOI.get(
    model::Optimizer,
    attr::VariableAttribute,
    vi::MOI.VariableIndex,
)
    if attr === "quantifier"
        return model.v[vi].quantifier
    elseif attr === "block"
        return model.v[vi].block
    end
end

# variable attribute 'quantifier'
function MOI.set(
    model::Optimizer,
    attr::VariableAttribute,
    vi::MOI.VariableIndex,
    value::String,
)
    if attr === "quantifier" && value === "all"
        model.v[vi].quantifier = "all"
    elseif attr === "quantifier" && value === "exists"
        model.v[vi].quantifier = "exists"
    end
    return
end

# variable attribute 'block'
function MOI.set(
    model::Optimizer,
    attr::VariableAttribute,
    vi::MOI.VariableIndex,
    value::Int,
)
    if attr === "block"
        model.v[vi].block = Int64(value)
    end
    return
end

# ========================================
#   Constraint attributes
# ========================================
struct ConstraintAttribute <: MOI.AbstractConstraintAttribute
    name::String
end

function MOI.supports(
    model::Optimizer,
    attr::ConstraintAttribute,
    ::Type{<:MOI.ConstraintIndex},
)
    if attr.name === "quantifier"
        return true
    else
        return false
    end
end

function MOI.get(
    model::Optimizer,
    attr::ConstraintAttribute,
    ci::MOI.ConstraintIndex,
)
    if attr === "quantifier"
        for con in model.c
            if con.index == ci
                return con.quantifier
            end
        end
    end
end

function MOI.set(
    model::Optimizer,
    attr::ConstraintAttribute,
    ci::MOI.ConstraintIndex,
    value::String,
)
    if attr === "quantifier"
        for con in model.c
            if con.index == ci
                con.quantifier = value
            end
        end
    end
    return
end

# ========================================
#   Solution & TerminationStatus
# ========================================
MOI.supports(::Optimizer, ::MOI.TerminationStatus) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true

# return termination status
function MOI.get(model::Optimizer, attr::MOI.TerminationStatus)
    try
        if model.optimize_not_called
            return MOI.OPTIMIZE_NOT_CALLED
        elseif model.results.solutionStatus == "OPTIMAL"
            return MOI.OPTIMAL
        elseif model.results.solutionStatus == "INFEASIBLE"
            return MOI.INFEASIBLE
        elseif model.results.solutionStatus == "INCUMBENT"
            return MOI.TIME_LIMIT
        else
            return MOI.OTHER_ERROR
        end
    catch err
        println(err)
    end
end

# return solve time
function MOI.get(model::Optimizer, attr::MOI.SolveTimeSec)
    try
        return Float64(model.results.runtime)
    catch err
        println(err)
    end
end

# return objective value
function MOI.get(model::Optimizer, attr::MOI.ObjectiveValue)
    try
        return model.results.objective_value
    catch err
        println(err)
    end
end

# return variable value
function MOI.get(
    model::Optimizer,
    attr::MOI.VariablePrimal,
    x::MOI.VariableIndex,
)

    try
        return model.results.values["x" * string(x.value)]
    catch err
        println(err)
    end
end
