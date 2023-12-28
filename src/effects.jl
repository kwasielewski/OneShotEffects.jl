using MacroTools
using IRTools
using DataStructures

function push!(stack::Stack, item)
    DataStructures.push!(stack, item)
end

function pop!(stack::Stack)
    DataStructures.pop!(stack)
end

handler_stack = Stack{Task}()
parent_dict = Dict{Task,Task}()

abstract type Effect end
struct Val <: Effect end

abstract type Action end
struct Perform <: Action end
struct Resend <: Action end

struct Wrap
    type::Action
    effect::DataType
    args::Vector
    continuation::Union{Nothing,Task,Function}
end

function perform(e::Effect)
    if hasfield(typeof(e), :args)
        args = [e.args]
    else
        args = []
    end
    return yield_parent(Wrap(Perform(), typeof(e), args, nothing))
end

function resend(e, args, t)
    top = first(handler_stack)
    pop!(handler_stack)
    res = yield_parent(Wrap(Resend(), e, args, t))
    push!(handler_stack, top)
    return res
end

function is_eff_obj(obj)
    return isa(obj, Wrap)
end

function yield_parent(args...)
    yieldto(parent_dict[current_task()], args...)
end

function yieldStack(args...)
    yieldto(first(handler_stack), args...)
end

function resume(t::Task, args...)
    curr = current_task()
    parent_dict[t] = curr
    if isnothing(args)
        r = yieldto(t)
    else
        r = yieldto(t, args...)
    end

    if Base.istaskfailed(t)
        println("Task failed")
        return r
    else
        return r
    end
end

function handler(h::Dict{DataType,Function})
    function tmp(th)
        curr_task = current_task()

        push!(handler_stack, curr_task)
        co = Task(() -> begin
            res = th()
            yield_parent(res)
        end)
        parent_dict[co] = curr_task
        local handle
        cont = (args...) -> begin
            r = resume(co, args...)
            r = handle(r)
            r
        end

        rehandle = k -> begin
            (args...) -> begin
                newh = copy(h)
                newh[Val] = cont

                return handler(newh)(() -> k(args...))
            end
        end

        handle = r -> begin
            if !is_eff_obj(r)
                if isnothing(r)
                    r = [nothing]
                end
                if !isa(r, Vector)
                    r = [r]
                end
                res = h[Val](r...)
                return res
            end

            if isa(r.type, Perform) && haskey(h, r.effect)
                effh = h[r.effect]
                return effh(cont, r.args...)
            elseif isa(r.type, Perform)
                return resend(r.effect, r.args, cont)
            elseif isa(r.type, Resend) && haskey(h, r.effect)
                effh = h[r.effect]
                return effh(rehandle(r.continuation), r.args...)
            elseif isa(r.type, Resend)
                return resend(r.eff, r.args, rehandle(r.continuation))
            else
                error("unreachable")
            end
        end
        res = cont(nothing)

        return res
    end
    function tmp()
        return h
    end
    return tmp
end
