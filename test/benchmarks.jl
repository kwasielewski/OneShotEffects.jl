using OneShotEffects
using BenchmarkTools

struct Get <: Effect end
struct Dummy <: Effect end

VARIANT = 1

if VARIANT == 0
    ben = @benchmark begin

    simpleh = handler(Dict(
        Value => (v -> v),
        Dummy => (k -> k())
    ))

    simpleh2 = handler(Dict(
        Value => (v -> v),
        Dummy => (k -> k())
    ))
    toph = handler(Dict(
        Value => (v -> v),
        Get => (k -> k(42))
    ))

    retval = toph(() -> 
        simpleh(() ->
        simpleh(() -> 
        simpleh(() -> 
        simpleh(() -> 
        simpleh(() -> 
        simpleh(() -> 
        simpleh(() -> 
        simpleh(() -> 
        simpleh(() -> 
        simpleh(() -> 
            perform(Get())
        )))))))))))

    end
else
    ben = @benchmark begin

    simpleh = handler(Dict(
        Value => (v -> v),
        Dummy => (k -> k())
    ))

    simpleh2 = handler(Dict(
        Value => (v -> v),
        Dummy => (k -> k())
    ))
    toph = handler(Dict(
        Value => (v -> v),
        Get => (k -> k(42))
    ))

    retval = toph(() -> 
        simpleh(() ->
        simpleh(() -> 
        simpleh(() -> 
        simpleh(() -> 
        simpleh(() -> 
            perform(Get())
        ))))))
    end
end