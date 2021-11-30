using BenchmarkTools
using ToyStencils
@assert !ToyStencils.DEBUG_ENABLED

np = 15
n = 2^np
prob = ToyStencils.example_prob(; nx = n, nt = n)

@show sizeof(prob) ÷ 2^10

trials = map(np:-1:max(1, np - 5)) do p
    print("  smallsize = 2^$p\t")
    t = @benchmark(
        ToyStencils.stencil!(prob; smallsize = 2^$p, basesize = Inf, timewindow = Inf)
    )
    show(t)
    print(" memory=", BenchmarkTools.memory(t), " #allocs=", BenchmarkTools.allocs(t))
    println()
    return 2^p => t
end

if !isinteractive()
    for (n, t) in trials
        @show n
        display(t)
        println()
    end
end
