using Revise
using MathOptInterface
const MOI = MathOptInterface

export YasolVariable, YasolConstraint

# JUMP extensions

# variable extension
struct YasolVariable
    info::JuMP.VariableInfo
    quantifier::String
    block::Int64
end

function JuMP.build_variable(
    _error::Function,
    info::JuMP.VariableInfo,
    ::Type{YasolVariable};
    quantifier::String,
    block::Int64,
    kwargs...,
)
    return YasolVariable(
        info,
        quantifier,
        block,
    )
end

function JuMP.add_variable(
    model::JuMP.Model,
    yasolVar::YasolVariable,
    name::String,
)
    var = JuMP.add_variable(
            model,
            JuMP.ScalarVariable(yasolVar.info),
            name,
        )

    # add variable attributes to variable
    MOI.set(model, YasolSolver.VariableAttribute("quantifier"), var, yasolVar.quantifier)
    MOI.set(model, YasolSolver.VariableAttribute("block"), var, yasolVar.block)

    # print warning, if variable in first block is not existential
    if(yasolVar.block == 1 && yasolVar.quantifier != "exists")
        @error string("Variables in the first block need to be existential! Please add a dummy variable!")
        return
    end

    # check if quantifier is "exists" or "all"
    if((yasolVar.quantifier != "exists") && (yasolVar.quantifier != "all"))
        @error string("Variable quantifier has to be either 'exists' or 'all'!")
    end

    # check if block is an integer
    if(!isinteger(yasolVar.block))
        @error string("Variable blocks need to be of type integer!")
    end

    return var
end

# constraint extension
struct YasolConstraint
    f::AffExpr
    s::MOI.AbstractScalarSet
    quantifier::String
end

function JuMP.build_constraint(
    _error::Function,
    f::AffExpr,
    s::MOI.AbstractScalarSet,
    ::Type{YasolConstraint};
    quantifier::String,
)
    return YasolConstraint(f, s, quantifier)
end

function JuMP.add_constraint(
    model::Model,
    yasolCon::YasolConstraint,
    name::String,
)
    con = JuMP.add_constraint(
        model,
        ScalarConstraint(yasolCon.f, yasolCon.s),
        name,
    )

    # add constarint attributes to constraint
    MOI.set(model, YasolSolver.ConstraintAttribute("quantifier"), con, yasolCon.quantifier)

    # check if quantifier is "exists" or "all"
    if((yasolCon.quantifier != "exists") && (yasolCon.quantifier != "all"))
        @error string("Constraint quantifier has to be either 'exists' or 'all'!")
    end

    return con
end
