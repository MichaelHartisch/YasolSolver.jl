module YasolSolver
using Revise

import MathOptInterface
const MOI = MathOptInterface
using EzXML

include("MOI_wrapper/MOI_wrapper.jl")

include("JuMP.jl")

# change parameter in Yasol.ini file
function setInitialParameter(yasolDir::String, parameter::String, value::Int64)
    # create temp copy
    mv(joinpath(yasolDir, "Yasol.ini"), joinpath(yasolDir, "Yasol_temp.ini"))

    # clear original file
    open(joinpath(yasolDir, "Yasol.ini"), "w") do f
        write(f, "")
    end

    # copy updated values
    open(joinpath(yasolDir, "Yasol_temp.ini"), "r") do f
        open(joinpath(yasolDir, "Yasol.ini"), "a") do i
            while !eof(f)
              x = readline(f)
              par = rsplit(x, "=")
              if par[1] == parameter
                  # overwrite parameter value
                  write(i, parameter * "=" * string(value) * "\n")
              else
                  write(i, x * "\n")
              end
            end
        end
    end

    # delete temp file
    rm(joinpath(yasolDir, "Yasol_temp.ini"))
end

# return all initial parameter
function getInitialParameter(yasolDir::String)
    result = []
    open(joinpath(yasolDir, "Yasol.ini")) do file
        for ln in eachline(file)
            if ln != "END"
                push!(result, ln)
            end
        end
    end
    return result
end

# import and return solution
function importSolution(solPath::String)
    doc = readxml(solPath)

    objective_value = 0.0
    runtime = 0
    solutionStatus = ""
    gap = 0.0
    values = Dict{String,Float64}()

    for node in eachelement(doc.root)
        if node.name == "header"
            objective_value = parse(Float64, node["ObjectiveValue"])
            runtime = parse(Float64, rsplit(node["Runtime"], " ")[1])
        elseif node.name == "quality"
            solutionStatus = node["SolutionStatus"]
            gap = parse(Float64, node["Gap"])
        elseif node.name == "variables"
            for var in eachelement(node)
                values[var["name"]] = parse(Float64, var["value"])
            end
        end
    end

    res = _Results(objective_value, runtime, solutionStatus, gap, values)

    return res
end

# print solution
function printSolution(res::YasolSolver._Results)
    println("---Solution---")
    println("Objective value: " * string(res.objective_value))
    println("Runtime: " * string(res.runtime))
    println("Solution status: " * string(res.solutionStatus))
    println("Gap: " * string(res.gap))
    println("Variable values: ")
    for (key, value) in res.values
        println(key * ": " * string(value))
    end
    println("---End---")
end

end
