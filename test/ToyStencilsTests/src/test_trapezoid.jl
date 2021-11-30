module TestTrapezoid

using Test
using ToyStencils: example_prob, stencil!

function check(; kwargs...)
    prob = example_prob(; kwargs...)

    us_ker = copy(stencil!(prob; timewindow = Inf, basesize = Inf, smallsize = Inf))
    us_seq = copy(stencil!(prob; timewindow = Inf, basesize = Inf, smallsize = 0))
    us_par = copy(stencil!(prob; timewindow = 0, basesize = 0, smallsize = 0))

    @test us_seq == us_ker
    @test us_par == us_ker
end

function test()
    @testset for nx in [5, 10], nt in [1, 3, 4, 5, 11]
        check(; nx = nx, nt = nt)
    end
end

end  # module
