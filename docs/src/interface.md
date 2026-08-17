# [Developer Extension API](@id developer_extension_api)

PDEBase defines a small, versioned protocol for packages that discretize a
`ModelingToolkit.PDESystem`. The protocol turns symbolic equations and boundary
conditions into a symbolic ODE, DAE, or optimization system. It is an extension
API for discretizer authors, not an application-level solver API.

!!! warning "Developer API"

    The functions on this page are public so that discretizer packages can
    extend them. Ordinary applications should call a discretizer such as
    MethodOfLines.jl and should not build a solver directly on these hooks.
    Extension packages should preserve the call order and return contracts below.

## Contract

The generic pipeline calls the hooks in this order:

1. `VariableMap(pdesys, discretization)` normalizes symbolic variables and
   domains.
2. `interface_errors` rejects unsupported systems before work is allocated.
3. `parse_bcs` creates the boundary map, then `check_boundarymap` validates it.
4. `should_transform` optionally enables `transform_pde_system!`.
5. `construct_disc_state`, `construct_discrete_space`, and
   `construct_var_equation_mapping` create the discretizer state.
6. `construct_differential_discretizer` precomputes derivative data.
7. For each PDE, `get_eqvar` selects its discrete variable and
   `discretize_equation!` updates the state in place.
8. `generate_ic_defaults` creates discrete initial values.
9. `generate_metadata` stores data needed by the generated problem and solution.
10. `generate_system` constructs the final symbolic system.

The default methods are intentionally conservative no-ops. A production
discretizer must override the hooks that construct its space, map, derivative
data, equations, metadata, and final system. A hook should return only the value
specified in its docstring; in-place hooks should mutate their supplied state
and return `nothing`.

## Input Rules

The `PDESystem` supplied to the protocol is expected to satisfy these rules:

- Every independent variable has one finite domain interval.
- Dependent variables use a consistent argument order throughout equations and
  boundary conditions.
- Every spatial boundary required by the discretizer is represented in the
  boundary conditions.
- Time-dependent systems provide initial conditions on the time variable.
- Periodic conditions occur as matching lower/upper pairs.
- Interface conditions connect variables with compatible argument signatures;
  only the interface coordinate may differ.

`VariableMap` excludes time from `indvars(v)` but retains it in `all_ivs(v)` and
in each dependent variable's argument signature. A discretizer should use the
accessors rather than infer dimension order from a field layout.

## Abstract Types

Discretizers should subtype one of the output categories and the supporting
abstract types as appropriate:

```julia
struct MyDiscretization <: PDEBase.AbstractEquationSystemDiscretization
    kwargs::NamedTuple
end

struct MySpace <: PDEBase.AbstractCartesianDiscreteSpace
    grid::Vector{Float64}
end

struct MyMapping <: PDEBase.AbstractVarEqMapping
    equation_variables::Dict
end

struct MyDerivativeData <: PDEBase.AbstractDifferentialDiscretizer
    weights::Dict
end

struct MyState <: PDEBase.AbstractDiscretizationState
    equations::Vector
end
```

`AbstractEquationSystemDiscretization` is for ODE/DAE-like symbolic systems;
`AbstractOptimizationSystemDiscretization` is for optimization systems.
`AbstractDiscreteSpace`, `AbstractVarEqMapping`,
`AbstractDifferentialDiscretizer`, and `AbstractDiscretizationState` describe
the values exchanged by the protocol and are intentionally free of concrete
mesh or solver assumptions.

## Validation and Transformation

These hooks run before equation generation. Validation hooks should throw a
domain-specific error for unsupported input and return `nothing` for valid
input. `should_transform` must be a pure decision for the supplied system;
`transform_pde_system!` is called only when it returns `true` and must return the
system consumed by later hooks.

```@docs
PDEBase.interface_errors
PDEBase.check_boundarymap
PDEBase.should_transform
PDEBase.transform_pde_system!
```

## Construction

Construction hooks establish the values shared by every equation visit. The
mapping returned by `construct_var_equation_mapping` must support
`get_eqvar` for every PDE, and the derivative data returned by
`construct_differential_discretizer` must support every derivative order listed
in `orders`.

```@docs
PDEBase.construct_disc_state
PDEBase.construct_discrete_space
PDEBase.construct_var_equation_mapping
PDEBase.construct_differential_discretizer
```

## Equation and Finalization Hooks

`discretize_equation!` is the only per-equation hook. It should append or mutate
the state and leave system construction to `generate_system`. The finalization
hooks should keep the metadata and initial-value representations consistent;
`generate_system` receives the `checks` keyword and should forward it to the
symbolic system constructor.

```@docs
PDEBase.discretize_equation!
PDEBase.generate_ic_defaults
PDEBase.generate_metadata
PDEBase.generate_system
```

## Accessor Hooks

These accessors keep downstream packages independent of concrete field names:

```@docs
PDEBase.get_time
PDEBase.get_discvars
PDEBase.get_eqvar
PDEBase.add_metadata!
```

## Minimal Implementation

The following skeleton shows the intended generic dispatch. A real package must
also implement the numerical work inside `discretize_equation!` and construct a
concrete symbolic system in `generate_system`.

```julia
using PDEBase

struct MyDiscretization <: PDEBase.AbstractEquationSystemDiscretization
    time::Any
end

struct MySpace <: PDEBase.AbstractCartesianDiscreteSpace
    grid::Vector{Float64}
end

PDEBase.get_time(disc::MyDiscretization) = disc.time
PDEBase.construct_discrete_space(v, ::MyDiscretization) = MySpace(collect(0:0.1:1))

function PDEBase.construct_var_equation_mapping(eqs, bmap, space::MySpace,
        disc::MyDiscretization)
    return MyMapping(Dict(eq => space.grid for eq in eqs))
end

function PDEBase.discretize_equation!(state, pde, mapping, eqvar, bcmap,
        depvars, space, derivative_data, indexmap, disc)
    push!(state.equations, pde)
    return nothing
end
```

The generic interface tests in PDEBase exercise the default methods and a
minimal concrete dispatch using only these hooks. New discretizers should add a
similar contract test for their concrete invariants.

See the [Discretization Workflow](@ref workflow) for the data flow and the
[VariableMap](@ref variablemap) and [Boundary Conditions](@ref boundaries)
pages for the symbolic input structures.
