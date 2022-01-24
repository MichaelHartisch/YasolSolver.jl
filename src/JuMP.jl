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

    return con
end
