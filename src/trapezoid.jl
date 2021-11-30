@inline function kernel(a, b, c)
    f(x) = 1 - 1.895 * x^2
    ϵ = 0.1
    return (1 - ϵ) * f(b) + ϵ / 2 * (f(a) + f(c))
end

stencil!(us::AbstractMatrix; kwargs...) = stencil!(kernel, us; kwargs...)

function example_prob(; nx::Integer = 100, nt::Integer = 1000)
    us = zeros(nx, nt)
    us[:, begin] .= range(-0.5, 0.5; length = nx) .+ 0.01
    return us
end

function example(; nx::Integer = 100, nt::Integer = 1000, kwargs...)
    us = example_prob(; nx = nx, nt = nt)
    return stencil!(us; smallsize = 2^10, basesize = Inf, timewindow = Inf, kwargs...)
end

as_basesize_int64(x) = max(2, Int64(x))
function as_basesize_int64(x::AbstractFloat)
    if x == Inf
        return typemax(Int64)
    end
    error("expected an integer or `Inf`; got: ", x)
end

function stencil_parameters(; smallsize, basesize, timewindow)
    return (
        smallsize = as_basesize_int64(smallsize),
        basesize = as_basesize_int64(basesize),
        timewindow = as_basesize_int64(timewindow),
    )
end

const DUMMY_VALUE = 12345

function stencil!(f::F, us::AbstractMatrix; kwargs...) where {F}
    @ifdebug fill!(@view(us[begin+1:end-1, begin+1:end]), DUMMY_VALUE)
    smallsize, basesize, timewindow = stencil_parameters(; kwargs...)
    xs = firstindex(us, 1)+1:lastindex(us, 1)-1
    for tf in firstindex(us, 2)+1:timewindow:lastindex(us, 2)
        tl = Int(min(tf + Int128(timewindow) - 1, lastindex(us, 2)))
        trapezoid_par!(f, us, tf:tl, xs, smallsize, basesize)
    end
    return us
end

function trapezoid_par!(
    f::F,
    us::AbstractMatrix,
    ts::UnitRange,
    xs::UnitRange,
    smallsize::Integer,
    basesize::Integer,
) where {F}
    if length(xs) ≤ basesize
        dx0 = first(xs) > firstindex(us, 1) + 1 ? 1 : 0
        dx1 = last(xs) < lastindex(us, 1) - 1 ? -1 : 0
        trapezoid_seq!(f, us, ts, xs, dx0, dx1, smallsize)
    else
        xm = first(xs) + length(xs) ÷ 2 - 1
        @sync begin
            @spawn trapezoid_par!(f, us, ts, xm+1:last(xs), smallsize, basesize)
            trapezoid_par!(f, us, ts, first(xs):xm, smallsize, basesize)
        end
        # Compute the "inverted trapezoid" in between the DAC'ed cases above
        let ts = first(ts)+1:last(ts),  # "t=1" is already computed
            xs = xm:xm+1,             # "t=2" has two uncomputed states
            dx0 = -1,                   # expand to left
            dx1 = 1
            # expand to right
            trapezoid_basecase!(f, us, ts, xs, dx0, dx1)
        end
    end
    return
end

function trapezoid_seq!(
    f::F,
    us::AbstractMatrix,
    ts::UnitRange,
    xs::UnitRange,
    dx0,
    dx1,
    smallsize::Integer,
) where {F}
    @ifdebug @check dx0 ∈ (-1, 0, 1) && dx1 ∈ (-1, 0, 1)
    if max(length(xs), length(ts)) ≤ smallsize
        trapezoid_basecase!(f, us, ts, xs, dx0, dx1)
    else
        doublewidth = 2 * length(xs) + (dx1 - dx0) * length(ts)
        if doublewidth ≥ 4 * length(ts)  #  width ≥ 2 height  ⇒  space cut
            xm = first(xs) + length(xs) ÷ 2 - 1
            xsl = first(xs):xm
            xsr = xm+1:last(xs)
            trapezoid_seq!(f, us, ts, xsl, dx0, -1, smallsize)
            trapezoid_seq!(f, us, ts, xsr, -1, dx1, smallsize)
        else  # width < 2 height  ⇒  time cut
            half = length(ts) ÷ 2
            tm = first(ts) + half - 1
            tsl = first(ts):tm
            tsr = tm+1:last(ts)
            x0 = first(xs) + dx0 * half
            x1 = last(xs) + dx1 * half
            trapezoid_seq!(f, us, tsl, xs, dx0, dx1, smallsize)
            trapezoid_seq!(f, us, tsr, x0:x1, dx0, dx1, smallsize)
        end
    end
    return
end

function trapezoid_basecase!(f, us, ts, xs, dx0, dx1)
    @ifdebug @check dx0 ∈ (-1, 0, 1) && dx1 ∈ (-1, 0, 1)
    x0 = first(xs)
    x1 = last(xs)
    for t in ts
        # @simd ivdep for x in x0:x1
        for x in x0:x1
            @ifdebug assert_us_not_written(us, x, t)
            @inbounds us[x, t] = f(us[x-1, t-1], us[x, t-1], us[x+1, t-1])
        end
        x0 += dx0
        x1 += dx1
    end
end

function assert_us_not_written(us, x, t)
    u = us[x, t]
    if u != DUMMY_VALUE
        error("us[x, t] (x=$x, t=$t) already has value $u")
    end
end
