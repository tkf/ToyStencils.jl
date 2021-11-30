module ToyStencils

using ArgCheck: @check
using Preferences: @delete_preferences!, @load_preference, @set_preferences!

if isdefined(Base.Experimental, :Tapir)
    using Base.Experimental.Tapir: @sync, @spawn
else
    using Base.Threads: @sync, @spawn
end

include("debug.jl")
include("trapezoid.jl")

end
