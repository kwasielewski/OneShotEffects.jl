using OneShotEffects
using BenchmarkTools

struct Get <: Effect end
struct Put <: Effect 
    args::Int
end
state = 0
VARIANT =1
if VARIANT == 0
    ben = @benchmark begin

    stateh = handler(Dict(
        Value => (v -> (x->x)),
        Put => ((k, arg) -> (s -> k()(arg))),
        Get => (k -> (s -> k(s)(s)))
    ))
    function counter()
        i = perform(Get())
        while i != 0
            perform(Put(i - 1))
            i = perform(Get())
        end
    end

    retval = stateh(() -> begin
                counter()
                perform(Get())
            end)(1000)
    end

elseif VARIANT == 1
    ben = @benchmark begin
        function counter()
            global state
            i = state
            while i != 0
                state = i - 1
                i = state
            end
        end
        global state
        state = 1000
        counter()
    end
end