using MacroTools
using IRTools
using DataStructures
using ReplMaker


"""
    effects_list(e)

Recursively searches for instances of `Effect` subtypes in an expression `e`.

"""
function effects_list(e)
    list_of_effects = subtypes(Effect)
    if isa(e, Expr) && e.head == :call && e.args[1] == :perform
        tp = getfield(@__MODULE__, e.args[2].args[1])
        if tp in list_of_effects
            return [tp]
        end
    end
    if isa(e, Expr)
        return reduce(vcat, map(effects_list, e.args))
    end
    return []
end

effects = Set{DataType}()

"""
    used_effects(a...)

Compute the set of effects used by the given function.

"""
function used_effects(a...)
    global effects
    effects = Set{DataType}()

    infer_effects(a...)
    return collect(effects)
end

IRTools.@dynamo function infer_effects(a...)
    global effects
    ir = IRTools.IR(a...)
    isnothing(ir) && return # base case
    list_of_effects = subtypes(Effect) #list of DataTypes

    for (x, st) in ir
        IRTools.isexpr(st.expr, :call) || begin
            ir[x] = :(1.0 + 1.0)
            continue
        end
        if st.expr.head == :call && st.expr.args[1] == GlobalRef(Main, :perform)
            effect = getfield(@__MODULE__, ir[st.expr.args[2]].expr.args[2].name)
            if effect in list_of_effects
                DataStructures.push!(effects, effect)
            end
            ir[x] = :(2 + 2)
        else
            ir[x] = IRTools.xcall(infer_effects, st.expr.args...)
        end
    end

    return ir
end

"""
    handler_parse(s)

Parse the given string `s` and perform automatic transformations on the parsed expression.
The transformations include:
- Replacing function calls to subtypes of `Effect` with a call to `perform`.
- Creating a dictionary from the arguments of `handler` function calls.

"""
function handler_parse(s)
    e = Meta.parse(s)
    list_of_effects = subtypes(Effect) #list of DataTypes
    #automatic perform
    MacroTools.postwalk(e) do x
        if x isa Expr &&
           x.head == :call &&
           getfield(@__MODULE__, x.args[1]) in list_of_effects
            x.args[1] = Expr(:call, :perform, x.args[1])
        end
        return x
    end

    #automatic Dict creation
    MacroTools.postwalk(e) do x
        if x isa Expr && x.head == :call && x.args[1] == :handler
            x.args[2] = Expr(:call, :Dict, x.args[2].args...)
        end
        return x
    end
end

"""
    start_handler_mode()

Initialize mode with user friendly handler syntax.

"""
function start_handler_mode()
    initrepl(
        handler_parse,
        prompt_text = "> ",
        prompt_color = :blue,
        start_key = ")",
        mode_name = "Handler",
        valid_input_checker = complete_julia,
    )
end

"""
    registerEffect(s::Symbol)

Register a new effect type with the given symbol `s`.

"""
function registerEffect(s::Symbol)
    @eval begin
        struct $s <: Effect end
    end
end

"""
    registerEffects(s::Vector{Symbol})

Register multiple effects by calling `registerEffect` on each element.

"""
function registerEffects(s::Vector{Symbol})
    for sym in s
        registerEffect(sym)
    end
end


"""
    flattenHandlers(ds::Vector{Dict{DataType,Function}})

Flattens a vector of dictionaries used to create handlers with disjoint effects into a single dictionary.

"""
function flattenHandlers(ds::Vector{Dict{DataType,Function}})
    res = Dict{Symbol,Function}()
    disjoint_sum = sum([length(d) for d in ds])
    for d in ds
        for (k, v) in d
            res[k] = v
        end
    end
    @assert disjoint_sum == length(res)
    return res
end


"""
    flattenHandlers(ds::Vector{Function})

Flattens a vector of handlers with disjoint effects into a single handler.


"""
function flattenHandlers(ds::Vector{Function})
    tmp = map(d -> d(), ds)
    return handler(flattenHandlers(tmp))
end

"""
    handlerLike(old::Dict{DataType,Function}, new::Dict{DataType,Function})

Creates new handler with effects from new overriding effects from old.

"""
function handlerLike(old::Dict{DataType,Function}, new::Dict{DataType,Function})
    res = Dict{DataType,Function}()
    for (k, v) in old
        res[k] = v
    end
    for (k, v) in new
        res[k] = v
    end
    return res
end

"""
    handlerLike(old::Dict{DataType,Function}, new::Function)

Creates new handler with effects from new overriding effects from old.
    
"""
function handlerLike(old::Dict{DataType,Function}, new::Function)
    res = Dict{DataType,Function}()
    for (k, v) in old
        res[k] = v
    end
    new = new()
    for (k, v) in new
        res[k] = v
    end
    return handler(res)
end
