# YasolSolver.jl

[![CI](https://github.com/hendrikbecker99/YasolSolver.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/hendrikbecker99/YasolSolver.jl/actions/workflows/CI.yml)
[![Build status](https://ci.appveyor.com/api/projects/status/113vvaxnitohipid?svg=true)](https://ci.appveyor.com/project/hendrikbecker99/yasolsolver-jl)
[![codecov](https://codecov.io/gh/hendrikbecker99/YasolSolver.jl/branch/master/graph/badge.svg?token=6UWMlSTP5i)](https://codecov.io/gh/hendrikbecker99/YasolSolver.jl)


YasolSolver.jl is an interface between [MathOptInterface.jl](https://github.com/jump-dev/MathOptInterface.jl)
and [Yasol solver](http://tm-server-2.wiwi.uni-siegen.de/t3-q-mip/index.php?id=2).

Please consult the [providing website](http://tm-server-2.wiwi.uni-siegen.de/t3-q-mip/index.php?id=1) for further information about the solver and how to build models.

## Installation

First, download the Yasol solver from [here](http://tm-server-2.wiwi.uni-siegen.de/t3-q-mip/index.php?id=4).

Second, install Yasol interface using `Pkg.add`.

```julia
import Pkg
Pkg.add("YasolSolver")
```

## Use with JuMP

Models can be build using [JuMP.jl](https://github.com/jump-dev/JuMP.jl) package and will be solved using Yasol interface and Yasol solver.

This can be done using the ``YasolSolver.Optimizer`` object. Here is how to create a
*JuMP* model that uses Yasol as the solver.
```julia
using JuMP, YasolSolver

cd("C:/Yasol") # change path to Yasol .exe directory

model = Model(() -> YasolSolver.Optimizer()) # use the path to Yasol solver .exe

set_optimizer_attribute(model, "solver path", "C:/Yasol/Yasol_CLP")
set_optimizer_attribute(model, "time limit", 60)
set_optimizer_attribute(model, "output info", 1)
set_optimizer_attribute(model, "problem file name", "Example.qlp")
```

The solver supports 3 attributes that can be used with JuMP:
* solver path -> defines the path to the Yasol executable
* time limit -> defines the time limit in seconds
* output info -> defines output level (1 is recommended)
* problem file name -> defines filename of model; solution file will have the same name

Further, the solver specific parameter saved in *Yasol.ini* can be set and retrieved the following:

```julia
# change Yasol initial parameter
# format: solver directory, parameter name, value
YasolSolver.setInitialParameter("C:/Yasol", "writeOutputFile", 1)
# get initial parameter
# format: solver directory
@show YasolSolver.getInitialParameter("C:/Yasol")
```

**Note: Do not change the default parameter without knowing their purpose!**

## Build and solve a JuMP model

Do the following to build and solve a JuMP model using Yasol solver:

```julia
@variable(model, x1, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="exists", block=1)

@variable(model, x2, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="exists", block=2)

@variable(model, x3, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="all", block=3)

@variable(model, x4, binary=true, lower_bound=0, upper_bound=1, YasolVariable, quantifier="exists", block=4)

@constraint(model, con1, 1*x1 -2*x2 +1*x3 -1*x4 <= 1, YasolConstraint, quantifier="exists")

@constraint(model, con2, 1*x1 + 1*x2 +1*x3 -1*x4 <= 2, YasolConstraint, quantifier="exists")

@constraint(model, con3, 1*x1 + 1*x2 +1*x3 <= 2, YasolConstraint, quantifier="all")

@objective(model, Min, -1*x1 -2*x2 +2*x3 +1x4)

optimize!(model)
```

## Solver specific variable and constraint extensions

The package provides two JuMP extensions that are used in the example above:

##### YasolVariable

To use Yasol variables, the keyword ``YasolVariable`` needs to be used followed by the parameter
``quantifier``, that can have the values 'exists' or 'all' and the parameter ``block`` that needs to be an integer >= 1.
Every variable can either be binary or an interger variable.

##### YasolConstraint

To use Yasol constraints, the keyword ``YasolConstraint`` needs to be used followed by the parameter ``quantifier``, that can have the values 'exists' or 'all'. Constraints can also be used without the constraint extension.

## Read solution

After calling the optimize function, the solution will be available in the selected project directory. Additionally, the solution can be accessed using JuMP the following way:

```julia
@show termination_status(model)
@show value(x1)
@show objective_value(model)
@show solve_time(model)

```
