push!(LOAD_PATH, pwd())

using Cairo
using CSV
using DataFrames
using Gadfly
using DataFrames
using Namespace
using Statistics
using Tree

TREE_INFESTATION_YEAR = :INFESTATION_YEAR;


function load_tree_csv(χ, i)
    filename = string("Tree_r_", χ, "_year_", i, ".csv")
    filename = Base.Filesystem.abspath("data", filename)
    return CSV.read(filename)
end


function load_beetle_csv(χ, i)
    filename = string("Beetle_r_", χ, "_year_", i, ".csv")
    filename = Base.Filesystem.abspath("data", filename)
    return CSV.read(filename)
end

function sort_inventory_by_year(inventory; rev=true)
    return sort(inventory, (TREE_YEARS_INFEST), rev=rev)
end


function get_infestation_year(inventory)
    x0 = maximum(inventory[TREE_YEARS_INFEST])
    f(x) = abs((x - x0) % x0)
    return f.(inventory[TREE_YEARS_INFEST])
end

function get_infested_trees(inventory)
    return inventory[inventory[TREE_YEARS_INFEST] .> 0, :];
end


function plot_beetles()

    plots = []

    for χ in 1:3
        counts = []
        for i in 1:5
            census = load_beetle_csv(χ, i)
            append!(counts, size(census)[1])
        end

        p = layer(x=collect(1:5), y=counts)
        push!(plots, p)
    end
end

function plot_tree_infestation(χ)
    inventory = load_tree_csv(χ, 5)
    inventory = sort(inventory, (TREE_YEARS_INFEST), rev=true)
    inventory[:TREE_INFEST] = get_infestation_year(inventory)

    p = plot(
        inventory,
        x = TREE_X,
        y = TREE_Y,
        color = TREE_YEARS_INFEST,
        Guide.colorkey(title="Years Infested "),
    );

    filename = string("plots/tree_sequence_", χ, ".png")
    draw(PNG(filename, 16cm, 14cm, dpi=900), p);

end

function plot_tree_dispersal()

    dfs = []
    for χ in 1:3

        inventory = load_tree_csv(χ, 5)
        infested = inventory[inventory[TREE_YEARS_INFEST] .> 0, :];
        infested = sort_inventory_by_year(infested; rev=false);
        x0 = infested[end, TREE_X];
        y0 = infested[end, TREE_Y];

        infested[:DISTANCE] = Tree.get_distance(infested, x0, y0);
        infested[:INFESTATION_YEAR] = get_infestation_year(infested);
        infested[:χ] = χ

        infested = infested[1:end-1, :]

        push!(dfs, infested)
    end

    p1 = plot(
        layer(dfs[1], x = :INFESTATION_YEAR, y = :DISTANCE, Geom.boxplot, Theme(default_color="deepskyblue")),
        layer(x=collect(0:5), y=2 .* collect(0:5), Geom.line, Theme(default_color="black")),
        Guide.xlabel("Year"), Guide.ylabel("Distance (km)"), Guide.title("χ = 1"), Coord.cartesian(ymin=0, ymax=15)
    );
    p2 = plot(
        layer(dfs[2], x = :INFESTATION_YEAR, y = :DISTANCE, Geom.boxplot, Theme(default_color="lightgreen")),
        layer(x=collect(0:5), y=2 .* collect(0:5), Geom.line, Theme(default_color="black")),
        Guide.xlabel("Year"), Guide.ylabel(nothing), Guide.title("χ = 2"), Coord.cartesian(ymin=0, ymax=15, xmax=5.5)
    );
    p3 = plot(
        layer(dfs[3], x = :INFESTATION_YEAR, y = :DISTANCE, Geom.boxplot, Theme(default_color="orange")),
        layer(x=collect(0:5), y=2 .* collect(0:5), Geom.line, Theme(default_color="black")),
        Guide.xlabel("Year"), Guide.ylabel(nothing), Guide.title("χ = 3"), Coord.cartesian(ymin=0, ymax=15, xmax=5.5)
    );

    hstack(p1, p2, p3)

    draw(PNG("plots/dispersion_boxplot.png", 20cm, 12cm, dpi=1200), hstack(p1, p2, p3))


    combined = vcat(dfs[1], dfs[2], dfs[3]);



end


function plot_average_dispersal()

    trees = []
    for χ in [1,2,3]
        inventory = load_tree_csv(χ, 5)

        infested = get_infested_trees(inventory)
        infested = sort_inventory_by_year(infested; rev=false);
        x0 = infested[end, TREE_X];
        y0 = infested[end, TREE_Y];

        infested[:DISTANCE] = Tree.get_distance(infested, x0, y0);
        infested[:INFESTATION_YEAR] = get_infestation_year(infested) .+ (χ-2)*0.1;

        infested = infested[1:end-1, :]
        dispersal = by(infested, :INFESTATION_YEAR, :DISTANCE => mean, :DISTANCE => std, :DISTANCE => length, :DISTANCE => maximum, :DISTANCE => minimum)
        dispersal[:χ] = χ;
        dispersal[:DISTANCE_mean_std] = dispersal[:DISTANCE_std] ./ sqrt.(dispersal[:DISTANCE_length])
        push!(trees, dispersal)
    end

    dispersal = vcat(trees[1], trees[2], trees[3])

    years = collect(0:maximum(dispersal[:INFESTATION_YEAR])+1)

    plt = plot(
        layer(
            x = dispersal[:INFESTATION_YEAR],
            y = dispersal[:DISTANCE_mean],
            ymin = dispersal[:DISTANCE_mean] - dispersal[:DISTANCE_std],
            ymax = dispersal[:DISTANCE_mean] + dispersal[:DISTANCE_std],
            color = dispersal[:χ],
            Geom.errorbar,
            Geom.point,
        ),
        layer(
            x = years,
            y = 2 .* years,
            Geom.line,
            Theme(default_color="black")
        ),
        Scale.color_discrete(),
        Coord.cartesian(
            xmin=minimum(years),
            xmax=maximum(years),
            ymin=0
        ),
        Guide.xlabel("Infestation Year"),
        Guide.ylabel("Average New Infestation (km)"),
        Guide.colorkey(title="Power Index, χ")
    )


    draw(PNG("plots/dispersion.png", 12cm, 12cm, dpi=900), plt);


end


function infestations_by_year()
    trees = []
    for χ in [1,2,3]
        inventory = load_tree_csv(χ, 5)

        infested = get_infested_trees(inventory)
        infested = sort_inventory_by_year(infested; rev=false);
        x0 = infested[end, TREE_X];
        y0 = infested[end, TREE_Y];

        infested[:DISTANCE] = Tree.get_distance(infested, x0, y0);
        infested[:INFESTATION_YEAR] = get_infestation_year(infested)

        infested = infested[1:end-1, :]
        dispersal = by(infested, :INFESTATION_YEAR, :DISTANCE => mean, :DISTANCE => std, :DISTANCE => length, :DISTANCE => maximum, :DISTANCE => minimum)
        dispersal[:χ] = χ;
        dispersal[:DISTANCE_mean_std] = dispersal[:DISTANCE_std] ./ sqrt.(dispersal[:DISTANCE_length])
        push!(trees, dispersal)
    end

    dispersal = vcat(trees[1], trees[2], trees[3])
    dispersal[:YEAR] = string.(dispersal[:INFESTATION_YEAR])

    plot(
        dispersal,
        x = :YEAR,
        y = :DISTANCE_length,
        color = :χ,
        Guide.xlabel("Infestation Year"),
        Guide.ylabel("Number of Newly Infested Trees"),
        Scale.color_discrete,
        Geom.bar(position=:dodge),
        Scale.x_discrete(levels=string.(collect(1:5))),
        Guide.colorkey(title="Power Index, χ")
    )


    plot(
        dispersal,
        xgroup = :YEAR,
        x = :χ,
        y = :DISTANCE_length,
        Geom.subplot_grid(Geom.bar),
        color = :χ
    )
end




function plot_violin_dispersal()
    plots = []
    for χ in [1,2,3]

        inventory = load_tree_csv(χ, 5)

        infested = get_infested_trees(inventory)
        infested = sort_inventory_by_year(infested; rev=false);
        x0 = infested[end, TREE_X];
        y0 = infested[end, TREE_Y];

        infested[:DISTANCE] = Tree.get_distance(infested, x0, y0);
        infested[:INFESTATION_YEAR] = get_infestation_year(infested) #.+ (χ-2)*0.1;
        infested = infested[1:end-1, :]

        p1 = plot(
            infested,
            x = :INFESTATION_YEAR,
            y = :DISTANCE,
            Geom.violin,
        );
        push!(plots, p1)
    end

    plot(
        plots
    )

end


function total_holes(inventory)
    dead = inventory[TREE_STATUS] .== TREE_STATUS_DICT["D"]
    trees = inventory[dead, :]

    bore_density = trees[TREE_LARVAE_EMERG] ./ trees[TREE_SURFACE_AREA]

    plot(
        x = bore_density,
        Geom.histogram(bincount=25)
    )
end


function total_holes()
    trees = []
    for χ in [1,2,3]
        inventory = load_tree_csv(χ, 5)

        dead = inventory[TREE_STATUS] .== TREE_STATUS_DICT["D"]
        dead = inventory[dead, :]
        dead[:HOLES] = dead[TREE_LARVAE_EMERG] ./ dead[TREE_SURFACE_AREA]
        dead[:χ] = χ
        push!(trees, dead)
    end
    trees = vcat(trees[1], trees[2], trees[3])
    trees = trees[trees[:HOLES] .< 100, :]

    plt = plot(
        trees,
        ygroup=:χ,
        x=:HOLES,
        color=:χ,
        Scale.color_discrete,
        Guide.xlabel("Exit Holes / m<sup>2</sup>"),
        Guide.ylabel("Density"),
        Guide.colorkey(title="Power Index χ"),
        Geom.subplot_grid(Geom.histogram(bincount=25, density=true)),
    )

    draw(SVG("plots/exit_holes.pdf", 16cm, 16cm, dpi=900), plt);

end

function total_larvae()
    trees = []
    for χ in [1,2,3]
        inventory = load_tree_csv(χ, 5)

        dead = inventory[TREE_STATUS] .== TREE_STATUS_DICT["D"]
        dead = inventory[dead, :]
        dead[:LARVAE] = dead[TREE_LARVAE_CUMUL] ./ dead[TREE_SURFACE_AREA]
        dead[:χ] = χ
        push!(trees, dead)
    end
    trees = vcat(trees[1], trees[2], trees[3])
    trees = trees[trees[:LARVAE] .> 10, :]
    trees = trees[trees[:LARVAE] .< 1e5, :]

    coord = Coord.cartesian(xmin=1, xmax=5)

    plt = plot(
        trees,
        ygroup=:χ,
        x=:LARVAE,
        Geom.subplot_grid(coord, Geom.histogram(bincount=20, density=true)),
        color=:χ,
        Scale.color_discrete,
        Guide.xlabel("Cumulative Larvae / m<sup>2</sup>"),
        Guide.ylabel("Density"),
        Guide.colorkey(title="Power Index χ"),
        Scale.x_log10,
    );

    draw(PDF("plots/larval_density.pdf", 16cm, 16cm), plt);

end




#draw(PNG("larval_death_density.png", 6inch, 6inch), plt)
