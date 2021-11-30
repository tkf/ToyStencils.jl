using DisplayAs
using Plots
using ToyStencils

us = ToyStencils.example()

heatmap(us; color = cgrad(:hawaii)) |> DisplayAs.PNG
