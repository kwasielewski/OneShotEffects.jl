using OneShotEffects
using Test

struct Put <: Effect
    args::Any
end
struct Get <: Effect end

struct Write <: Effect 
    args::AbstractString
end
struct Read <: Effect end
struct Write2 <: Effect 
    args::AbstractString
end

struct Throw <: Effect
    args::Any
end

function double_print_test()
    output = []
    printh = handler(Dict(
        Value => (v -> nothing),
        Write => ((k, arg) -> begin append!(output, arg); k() end)
    ))
    printh2 = handler(Dict(
        Value => (v -> nothing),
        Write2 => ((k, arg) -> begin append!(output, reverse(arg)); k() end)
    ))
    
    printh2(() -> begin 
            printh(() -> begin
                x = perform(Write("Hello "));
                y = perform(Write2("dlrow"));
                y = perform(Write2(" olleh "));
                x = perform(Write("world"));
            end) 
            z = perform(Write2("?!"))
        end)
    return reduce(*, output)
    
end

function escaping_effect_test()
    output = []
    printh3 = handler(Dict(
        Value => (v -> v),
        Write => ((k, arg) -> begin append!(output, arg); k() end)
    ))
    printh4 = handler(Dict(
        Value => (v -> v),
        Write => ((k, arg) -> begin append!(output, reverse(arg)); k() end)
    ))
    
    
    printh4(() -> begin
            x = printh3(() -> begin
                x = () -> perform(Write("abc"));
            end)
            x()
        end)
    return reduce(*, output)
end

function used_effects_test()
    function f()
        perform(Get())
    end
    function g()
        f()
    end
    return used_effects(g)
end

function used_multiple_effects_test()
    function f()
        perform(Get())
        perform(Read())
    end
    function g()
        perform(Write("abc"))
        f()
    end
    return Set(used_effects(g))
end

function state_test()
    stateh = handler(Dict(
        Value => (v -> (x->x)),
        Put => ((k, arg) -> (s -> k()(arg))),
        Get => (k -> (s -> k(s)(s)))
    ))
    
    retval = stateh(() -> begin
                z = perform(Get())
                x = perform(Put(z + 1))
                y = perform(Get())
                y = perform(Put(y + 1))
                y = perform(Get())
            end)(7)
    return retval
end

function exception_test()
    exch = handler(Dict(
        Value => (v -> v),
        Throw => ((k, arg) -> arg)
    ))
    
    return exch(() -> begin
                perform(Throw(5))
                0
            end)

end

function resending_resended_test()
    dummyh = handler(Dict(
        Value => (v -> v),
        Read => (k -> k(52))
    ))
    toph = handler(Dict(
        Value => (v -> v),
        Get => (k -> k(42))
    ))
    retval = toph(() -> begin
                dummyh(() -> begin
                dummyh(() -> begin
                    x = perform(Get())
                    x
            end) end) end)
    return retval
end

@testset "OneShotEffects" begin
    @test double_print_test() == "Hello world hello world!?"
    @test escaping_effect_test() == "cba"
    @test used_effects_test() == [Get]
    @test Set(used_multiple_effects_test()) == Set([Get, Read, Write])
    @test state_test() == 9
    @test exception_test() == 5
    @test resending_resended_test() == 42
end
