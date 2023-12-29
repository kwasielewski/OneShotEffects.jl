# OneShotEffects.jl
OneShotEffects provides implementation of one shot algebraic effects via coroutines in Julia.

To create an effect handler first register an effect and then provide cases for the handler.
```julia
julia> using OneShotEffects

julia> @registerEffect Get

julia> myHandler = handler(Dict(
    Value => (v -> v),
    Get => k -> k(42)
))
(::OneShotEffects.var"#tmp#7"{Dict{DataType, Function}}) (generic function with 2 methods)
```
To run effectful computation wrap all occurences of effect calls in `perform()` function and pass thunk to the handler.

```julia
julia> retval = myHandler(() -> begin
                           2 * perform(Get())
                       end)
84
```