using BenchPerf
using BenchmarkTools
using Printf
using ToyStencils
@assert !ToyStencils.DEBUG_ENABLED

try
    using Base: @something
catch
    using Compat: @something
end

np = 14
n = 2^np
prob = ToyStencils.example_prob(; nx = n, nt = n)

@show sizeof(prob) / 2^20

print_percent(x) = print_percent(stdout, x)
function print_percent(io::IO, x)
    if x === nothing
        print(io, "??.?%")
    else
        @printf(io, "%.2f%%", x)
    end
end

print_label(label; kwargs...) = print_label(stdout, label; kwargs...)
function print_label(io::IO, label; prefix = ' ')
    print(io, prefix)
    printstyled(io, label; color = :light_black)
    print(io, ": ")
end

# trials = map([13, 9]) do p
trials = map(np:-1:max(1, np - 5)) do p
    print_label("smallsize"; prefix = "")
    @printf("2^%-2d", p)
    bench = @benchmarkable(
        ToyStencils.stencil!(prob; smallsize = 2^$p, basesize = Inf, timewindow = Inf)
    )
    t = BenchPerf.run(
        bench;
        event = [
            "branch-misses",
            "branches",
            "L1-dcache-load-misses",
            "L1-dcache-loads",
            "L1-icache-load-misses",
            "L1-icache-loads",
            "LLC-load-misses",
            "LLC-loads",
            "dTLB-load-misses",
            "dTLB-loads",
            "iTLB-load-misses",
            "iTLB-loads",
            "stalled-cycles-frontend",
            "stalled-cycles-backend",
            "cycles",
            "instructions",
        ],
    )
    print("  ")
    show(IOContext(stdout, :typeinfo => typeof(t.benchmark)), t.benchmark)
    print(" ")
    print_label("L1d miss")
    print_percent(t.perf.percent.l1_dcache_load_misses)
    print_label("L1i miss")
    print_percent(t.perf.percent.l1_icache_load_misses)
    print_label("br miss")
    print_percent(t.perf.percent.branch_misses)
    print_label("stl.fr.")
    print_percent(t.perf.percent.stalled_cycles_frontend)
    print_label("stl.bk.")
    print_percent(t.perf.percent.stalled_cycles_backend)
    print_label("insn/cy")
    @printf("%.2f", something(t.perf.instructions_per_cycle, NaN))
    print_label("stl./insn")
    @printf("%.2f", something(t.perf.stalled_cycles_per_instructions, NaN))
    println()
    return 2^p => t
end

println()
for (n, t) in trials
    p = Int(log2(n))
    print_label("smallsize"; prefix = "")
    @printf("2^%-2d", p)
    print_label("memory")
    print(BenchmarkTools.memory(t.benchmark))
    print_label("#allocs")
    print(BenchmarkTools.allocs(t.benchmark))
    println()
end

if lowercase(get(ENV, "VERBOSE", "false")) == "true"
    for (n, t) in trials
        @show n
        display(t)
        println()
    end
end
