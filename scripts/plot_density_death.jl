using Gadfly
import StatsFuns


f(x; x0=150, s=25) = StatsFuns.logistic((x - x0) / s);
x = collect(0:300);


plot(
    x = x,
    y = f.(x),
    Guide.xlabel("Larval Density (larvae / m<sup>2</sup>)"),
    Guide.ylabel("Death Rate"),
    Geom.line
)
