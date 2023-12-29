using CodeTracking
using Revise
using MacroTools
using IRTool

function test()
    Put(6)
    println(Get())
    Put(Get() + 1)
    println(Get())
end

test_body = quote
    Put(6)
    println(Get())
    Put(Get() + 1)
    println(Get())
end

#handlers for natural_handle_state
#v = [0]
#function handle_get()
#    return v[1]
#end
#function handle_put(x)
#    v[1] = x
#end

#first attempt that replaces calls to effects with calls to handler cases
#fails to replace effects in nested functions
function natural_handle_state(f, def_val)
    #v = [def_val]
    #handle_get = () -> v[1]
    #handle_put = (x) -> v[1] = x; nothing
    f_expr = @code_expr f()

    function naive_expr_replace!(exp)
        if isa(exp, Expr)
            if exp.head == :curly
                if exp.args[1] == :Get
                    return :handle_get
                elseif exp.args[1] == :Put
                    return :handle_put
                end
            end
            #for i in 1:length(exp.args)
            #    naive_expr_replace!(exp.args[i])
            #end
            return Expr(exp.head, [naive_expr_replace!(arg) for arg in exp.args]...)
        end
        return exp
    end

    e = naive_expr_replace!(f_expr)
    dump(e.args[2])
    eval(Expr(:block, e.args[2].args...))
end

#second attempt that replaces calls to effects with calls to handler cases
#using eval is not ideal
function natural_handle_state_2(f, def_val)
    eval(quote
        v = [$def_val]
        function Get{T}() where {T}
            return v[1]
        end
        function Put{T}(x::T) where {T}
            v[1] = x
        end
        $f()
        Base.delete_method(Base.methods(Get{Int})[1])
        Base.delete_method(Base.methods(Put{Int})[1])
    end)
    return
end

#third attempt similar to the second but using invokelatest
function natural_handle_state_3(f, def_val)
    v = [def_val]
    Get_orig = (@isdefined Get) ? Get : nothing
    Put_orig = (@isdefined Put) ? Put : nothing
    f()
    Get = Get_orig
    Put = Put_orig
    return
end

Put(x) = invokelatest(handle_put, (x))
Get() = invokelatest(handle_get)

#fourth attempt using a table of functions
function test_with_table(function_table)
    function_table[2](6)
    println(function_table[1]())
    function_table[2](function_table[1]() + 1)
    println(function_table[1]())
end
function natural_handle_state_4(f, def_val)
    v = [def_val]
    table = [() -> v[1], (x) -> (v[1] = x; nothing)]
    f(table)
end

v = [0]
function handle_get()
    return v[1]
end
function handle_put(x)
    v[1] = x
end

#fifth attempt using IRTools
#replaces calls in nested functions, but operates on IR
#does not handle effects that discard  continuation
IRTools.@dynamo function handle_ir_state(a...)
    ir = IRTools.IR(a...)

    isnothing(ir) && return # base case
    ir = MacroTools.prewalk(ir) do x
        x isa GlobalRef && x.name == :Get && return GlobalRef(Main, :handle_get)
        x isa GlobalRef && x.name == :Put && return GlobalRef(Main, :handle_put)
        return x
    end
    for (x, st) in ir
        IRTools.isexpr(st.expr, :call) || continue
        ir[x] = IRTools.xcall(handle_ir_state, st.expr.args...) # substitution of handler
    end

    return ir
end

function g()
    Put(6)
    println(Get())
    Put(Get() + 1)
    println(Get())
end

IRTools.@code_ir handle_ir_state() do
    g()
end
