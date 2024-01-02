using OneShotEffects
using BenchmarkTools

struct Get <: Effect end
struct Put <: Effect 
    args::Int
end
state = 0
VARIANT = 2
if VARIANT == 0
    ben = @benchmark begin

    stateh = handler(Dict(
        Value => (v -> (x->x)),
        Put => ((k, arg) -> (s -> k()(arg))),
        Get => (k -> (s -> k(s)(s)))
    ))

    retval = stateh(() -> begin
                x = perform(Get())
                perform(Put(x + 1))
                x = perform(Get())
                perform(Put(x + 1))
                x = perform(Get())
                perform(Put(x + 1))
                x = perform(Get())
                perform(Put(x + 1))
                x = perform(Get())
                perform(Put(x + 1))
                x = perform(Get())
                perform(Put(x + 1))
                x = perform(Get())
                perform(Put(x + 1))
                x = perform(Get())
                perform(Put(x + 1))
                x = perform(Get())
                perform(Put(x + 1))
                x = perform(Get())
                perform(Put(x + 1))
                y = perform(Get())
            end)(7)
    end
elseif VARIANT == 1
    ben = @benchmark begin
        computation = (init) -> begin
            state = init
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            y = state
        end
    computation(7)
    end
else 
    ben = @benchmark begin
        computation = (init) -> begin
            global state
            state = init
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            x = state
            state = x + 1
            y = state
        end
    computation(7)
    end
end