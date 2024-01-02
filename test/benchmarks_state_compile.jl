using OneShotEffects

struct Get <: Effect end
struct Put <: Effect 
    args::Int
end
state = 0
VARIANT = 0
if VARIANT == 0
    ben = @time begin

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
    ben = @time begin
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
    ben = @time begin
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