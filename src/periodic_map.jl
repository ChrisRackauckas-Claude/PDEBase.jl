"""
    PeriodicMap{hasperiodic}

A structure that tracks periodic boundary conditions for variables in a PDE system.

# Type Parameters
- `hasperiodic`: A `Val` type parameter indicating whether any periodic conditions exist

# Fields
- `map`: A nested dictionary structure mapping dependent variable operations to their
  independent variables and whether each boundary is periodic

# Arguments
- `hasperiodic`: A `Val` type parameter indicating whether the map contains a
  periodic pair.
- `map`: A nested dictionary from dependent-variable operations to independent
  variables and `Val` periodicity markers.

# Constructor
- `PeriodicMap(bmap, v::VariableMap)`: Build the map from a parsed boundary map
  and variable map.

Constructs a `PeriodicMap` from a boundary map and variable map, automatically detecting
which boundaries have periodic conditions.

# Returns
- `PeriodicMap{Val{true}}` or `PeriodicMap{Val{false}}`, depending on the map.

# Examples
```julia
periodic = PeriodicMap(boundarymap, v)
periodic.map
```
"""
struct PeriodicMap{hasperiodic}
    map::Any
end

function PeriodicMap(bmap, v)
    map = Dict(
        [
            operation(u) => Dict([x => isperiodic(bmap, u, x) for x in all_ivs(v)])
                for u in v.ū
        ]
    )
    vals = reduce(vcat, collect.(values.(collect(values(map)))))
    hasperiodic = Val(any(p -> p isa Val{true}, vals))
    return PeriodicMap{hasperiodic}(map)
end
