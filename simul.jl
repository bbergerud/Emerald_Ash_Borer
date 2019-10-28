push!(LOAD_PATH, pwd())

# ===============================================
# Download the necessary packages
# ===============================================
if false
    using Pkg
    Pkg.add("CSV")
    Pkg.add("DataFrames")
    Pkg.add("Distributions")
    Pkg.add("Gadfly")
    Pkg.add("Random")
    Pkg.add("StatsFuns")
    Pkg.add("StatsBase")
    Pkg.add("Statistics")
end

# ===============================================
# Load the necessary modules
# ===============================================
using CSV
using DataFrames
#using Gadfly
import Distributions
import Random
import StatsBase
import StatsFuns
using Beetle
using Larvae
using Namespace
using Tree

Random.seed!(3520)
χ = 3;
initial_trees  = [3000];
initial_larvae = [50];

# ===============================================
# Functions for cleaning the tree inventory
# ===============================================
dbh_test(dbh) = dbh > 5;
clean_columns = [TREE_DBH];
clean_funcs   = [dbh_test];

# ===============================================
# Function for estimating surface area using DBH
# ===============================================
tree_surface_area(x) = 0.0195x^2 - 0.0035x + 0.0071;

# ===============================================
# ===============================================
function tree_death(inventory)
    return inventory[TREE_YEARS_INFEST] .== TREE_PARAMS["MAX_YEARS_INFEST"];
end

# ===============================================
# Function for generating female emergence dates
# ===============================================
#betaBinomial = Distributions.BetaBinomial(30, 3, 6)
#female_age_generator(n) = -Random.rand(betaBinomial, n)
female_age_generator(n) = zeros(Int, n)

# ===============================================
# Function for generating random egg deposites
# ===============================================
female_egg_generator(n) = Random.rand(1:10, n)

# ===============================================
# Function for determining the dispersion
# ===============================================
function female_forage_dispersion(tree, inventory, number; χ=χ, ϵ=0.01)

    # ===========================================
    # Num Trees
    # ===========================================
    num_trees = size(inventory)[1]

    # ===========================================
    # Get the tree distances
    # ===========================================
    X = inventory[tree, TREE_X]
    Y = inventory[tree, TREE_Y]
    tree_distances = Tree.get_distance(inventory, X, Y)

    # ===========================================
    # Correct for the tree's distance to itself
    # being 0; remove trees that are too far away
    # or are dead
    # ===========================================
    tree_distances[tree_distances .> BEETLE_PARAMS["DAY_FLIGHT"]] .= Inf
    tree_distances[inventory[TREE_STATUS] .== TREE_STATUS_DICT["D"]] .= Inf

    # ===========================================
    # Weight propabilities by the distances
    # ===========================================
    w = (tree_distances.^2 .+ ϵ^2).^(-χ/2)
    p = w ./ sum(w)

    # ===========================================
    # Select tree based on probabilities
    # ===========================================
    next_tree = StatsBase.sample(collect(1:num_trees), StatsBase.Weights(p), number)

    # ===========================================
    # Have a retainment fraction
    # ===========================================
    #if inventory[tree, TREE_STATUS] != TREE_STATUS_DICT["D"]
    #    next_tree[Random.rand(number) .< 0.25] .= tree
    #end

    return next_tree
end;

# ===============================================
# Functions for larave deaths
# ===============================================
larvae_death_random(n) = 0.60 * Random.rand(n);

function larvae_death_density(inventory; ρ_inflection=150, σ=25)
    ρ = inventory[TREE_LARVAE] ./ inventory[TREE_SURFACE_AREA]
    return StatsFuns.logistic.((ρ .- ρ_inflection) ./ σ)
end;


# ===============================================
# Prepare the tree dataset
# ===============================================
inventory_file = Base.Filesystem.abspath("files", "cedar_rapids_ash_trees.csv");
tree_inventory = Tree.load_inventory(inventory_file);
tree_inventory = Tree.unit_conversion(tree_inventory, TREE_DBH, 2.54);
tree_inventory = Tree.estimate_surface_area(tree_inventory, tree_surface_area);

# ===============================================
# Clean the dataset
# ===============================================
tree_inventory = Tree.clean_inventory(tree_inventory, clean_columns, clean_funcs);
tree_inventory = Tree.add_columns_to_inventory(tree_inventory);
tree_directory = Tree.tree_lookup(tree_inventory);

# ===============================================
# Set the initial infestation and update inventory
# ===============================================
tree_inventory = Larvae.initial_infestation(tree_inventory, initial_trees, initial_larvae);
tree_inventory = Tree.update_infestation_years(tree_inventory, tree_death)


function simulate_day()
    global female_census;
    global tree_inventory;
    female_census = Beetle.increment_age(female_census);
    female_census = Beetle.get_beetle_status(female_census);
    female_census = Beetle.disperse_beetles(
        tree_inventory, female_census, female_forage_dispersion, female_forage_dispersion
    )
    tree_inventory = Beetle.deposit_eggs(tree_inventory, female_census, female_egg_generator)
end;

function simulate_season()
    global tree_inventory
    global female_census

    tree_inventory = Larvae.larvae_death_deterministic(tree_inventory, larvae_death_density)
    tree_inventory = Larvae.larvae_death_random(tree_inventory, larvae_death_random)
    tree_inventory, female_census = Beetle.female_emergence(tree_inventory, tree_directory, female_age_generator);

    while any(female_census[BEETLE_STATUS] .!= BEETLE_STATUS_DICT["D"])
        simulate_day()
    end

    tree_inventory = Tree.update_infestation_years(tree_inventory, tree_death)
end;


for i = 1:5
    start = time()
    simulate_season()
    println("Iter = ", i, "\tTime: ", time() - start)
    filename = string("Tree_r_", abs(χ), "_year_", i, ".csv")
    CSV.write(Base.Filesystem.abspath("data", filename), tree_inventory)
    filename = string("Beetle_r_", abs(χ), "_year_", i, ".csv")
    CSV.write(Base.Filesystem.abspath("data", filename), female_census)

end

"""
function plot_trees()
    inventory = sort(tree_inventory, (TREE_YEARS_INFEST), rev=true)
    plot(
        inventory,
        x = TREE_X,
        y = TREE_Y,
        color = TREE_YEARS_INFEST,
        #shape = TREE_YEARS_INFEST,
        Scale.color_discrete()
    )
end;


function plot_trees(filename)
    inventory = CSV.read(filename)
    sort!(inventory, (TREE_YEARS_INFEST), rev=true)
    plot(
        x = inventory[TREE_X],
        y = inventory[TREE_Y],
        color = inventory[TREE_YEARS_INFEST],
        Scale.color_discrete()
    )
end;

using Gadfly
#for i = 1:3
#    filename = string("Tree_r_", abs(χ), "_year_", i, ".csv")
#    filename = Base.Filesystem.abspath("data", filename)
#    plot_trees(filename)
#end

function get_tree_file(i)
    filename = string("Tree_r_", abs(χ), "_year_", i, ".csv")
    return Base.Filesystem.abspath("data", filename)
end

function plot_tree_distances(filename)
    inventory = CSV.read(filename)
    x0 = inventory[initial_trees[1], TREE_X]
    y0 = inventory[initial_trees[1], TREE_Y]

    inventory = inventory[inventory[TREE_YEARS_INFEST] .> 0, :]
    distances = Tree.get_distance(inventory, x0, y0)
    plot(
        x = distances,
        Geom.histogram()
    )
end

function plot_tree_hexbin(filename)
    inventory = CSV.read(filename)
    x0 = inventory[initial_trees[1], TREE_X]
    y0 = inventory[initial_trees[1], TREE_Y]

    inventory = inventory[inventory[TREE_YEARS_INFEST] .> 0, :]
    plot(
        x = inventory[TREE_X],
        y = inventory[TREE_Y],
        color = inventory[TREE_YEARS_INFEST]
    )
end
""";
"""
using Gadfly
x = collect(1:300)
f(ρ; ρ_inflection=150, σ=25) = StatsFuns.logistic.((ρ .- ρ_inflection) ./ σ)
plt = plot(
    x=x,
    y=f.(x),
    Guide.xlabel("Larval Density (larvae / m<sup>2</sup>)"),
    Guide.ylabel("Larval Death Rate"),
    Geom.line
);

draw(PNG("/space/bergerud/Projects/emerald_ash_borer/images/larval_death_density.png", 6inch, 6inch, dpi=600), plt);


x = range(0, stop=100, length=50);
g(x; ϵ=10) = sqrt(x^2 + ϵ^2)
plot(
    x=x,
    y=g.(x),
    Geom.line,
    Coord.cartesian(
        xmin=minimum(x),
        xmax=maximum(x),
        ymin=minimum(x),
        ymax=maximum(x)
    ),
    Guide.xlabel("Distance (m)"),
    Guide.ylabel("Modulated Distance (m)")
)
""";
