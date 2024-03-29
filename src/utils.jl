using MacroTools
using IRTools
using ReplMaker
using InteractiveUtils


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

"""
    used_effects(a...)

Compute the set of effects used by the given function.

"""
function used_effects(a...)
    retval = infer_effects(a...)
    return collect(retval)
end

function unionSet!(s, x)
    if x isa Set
        union!(s, x)
    else
        s
    end
end

IRTools.@dynamo function infer_effects(a...)
    ir = IRTools.IR(a...)
    isnothing(ir) && return
    list_of_effects = subtypes(Effect) #list of DataTypes
    list_of_used_effects = []
    list_of_ids = []
    for (x, st) in ir
        IRTools.isexpr(st.expr, :call) || begin
            ir[x] = :(1.0 + 1.0)
            continue
        end
        if st.expr.head == :call && st.expr.args[1] == GlobalRef(Main, :perform)
            effect = getglobal(Main, ir[st.expr.args[2]].expr.args[2].name)
            if effect in list_of_effects
                Base.push!(list_of_used_effects, effect)
            end
            ir[x] = :(2 + 2)
        else
            ir[x] = IRTools.xcall(infer_effects, st.expr.args...)
            Base.push!(list_of_ids, x)
        end
    end
    effects_set = IRTools.push!(ir, IRTools.xcall(Core, :apply_type, Main.Set, Main.DataType))
    effects_set = IRTools.push!(ir, IRTools.xcall(effects_set))
    last_id = effects_set
    for i in 1:length(list_of_used_effects)
        last_id = IRTools.push!(ir, IRTools.xcall(:push!, effects_set, list_of_used_effects[i]))
    end
    for i in 1:length(list_of_ids)
        last_id = IRTools.push!(ir, IRTools.xcall(OneShotEffects, :unionSet!, effects_set, list_of_ids[i]))
    end
    IRTools.return!(ir, last_id)
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
    function insert_perform(e)
        if e isa Expr && e.head == :call && e.args[1] == :handler
            return e
        end
        if e isa Expr
            for i in 1:length(e.args)
                if e.args[i] isa Expr
                    e.args[i] = insert_perform(e.args[i])
                end
            end
        end
        if e isa Expr && e.head == :call
            try
                tp = getfield(Main, e.args[1])
                if tp in list_of_effects
                    return Expr(:call, :perform, e)
                end
            catch err
                return e
            end
        end
        return e
    end
    e = insert_perform(e)
    #automatic Dict creation
    function insert_dict(e)
        if e isa Expr
            for i in 1:length(e.args)
                if e.args[i] isa Expr
                    e.args[i] = insert_dict(e.args[i])
                end
            end
        end
        if e isa Expr && e.head == :call && e.args[1] == :handler
            e.args[2] = Expr(:call, :Dict, e.args[2:end]...)
            deleteat!(e.args, 3:length(e.args))
        end
        return e
    end
    e = insert_dict(e)
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
Registered effect has no arguments.

"""
macro registerEffect(s::Symbol)
    return esc(:(begin
        struct $s <: Effect end
    end))
end

"""
    macro registerEffectWithArgs(s::Symbol)

Register a new effect type with the given symbol `s`.
Registered effect has arguments.

"""
macro registerEffectWithArgs(s::Symbol)
    return esc(:(begin
        struct $s <: Effect 
            args::Any
        end
    end))
end

"""
    registerEffects(symbols...)

Register multiple effects by calling `@registerEffect` on each element.

"""
macro registerEffects(symbols...)
    return esc(:(begin
        $([:(@registerEffect $s) for s in symbols]...)
    end))
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
