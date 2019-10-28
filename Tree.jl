# Keep track of the total larvae that have hatched,
# as well as the total number that have left the tree


module Tree
using CSV
using DataFrames
using Namespace
using Statistics

# ==================================================
# Functions acting on the tree inventory
# ==================================================
@doc """
    add_columns_to_inventory(inventory)

Adds some initial columns to the tree inventory that are used
in the simulation

# Arguments
-`inventory::DataFrame`: Tree inventory
"""
function add_columns_to_inventory(inventory::DataFrame)
    inventory[TREE_LARVAE]       = 0;
    inventory[TREE_LARVAE_CUMUL] = 0;
    inventory[TREE_LARVAE_EMERG] = 0;
    inventory[TREE_YEARS_INFEST] = 0;
    return inventory
end


@doc """
    clean_inventory(inventory, columns, funcs)


# Arguments
-`inventory::DataFrame`: Tree inventory

-`columns::Array{Symbol}`: Array containing column symbols

-`funcs::Array`: Array containing functions that operate on
the values in `inventory`[`column`]. The function should return
a boolean indicating whether to keep the row or not.
"""
function clean_inventory(inventory::DataFrame, columns::Array{Symbol}, funcs::Array)
    for (column, func) in zip(columns, funcs)
        inventory = inventory[func.(inventory[column]), :];
    end
    return inventory
end

@doc """
    load_inventory(filename; center=true)

Loads the csv file `filename` containing the tree inventory.
If `center` is set to true, the coordinates (`X`,`Y`) are
centered to have mean zero.

# Arguments
-`filename::String`: name of csv file containing tree inventory

-`center::Bool`: Boolean indicating whether to center the coordinates
"""
function load_inventory(filename::String; center::Bool=true)
    inventory = CSV.read(filename);
    if center
        inventory[TREE_X] = inventory[TREE_X] .- mean(inventory[TREE_X]);
        inventory[TREE_Y] = inventory[TREE_Y] .- mean(inventory[TREE_Y]);
    end
    return inventory
end

@doc """
    tree_lookup(inventory)

Creates a dictionary that maps a tree ID to its row number
in the data frame.

# Arguments
-`inventory::DataFrame`: Tree inventory
"""
function tree_lookup(inventory::DataFrame)
    contents = Dict()
    row = 1
    for tree in eachrow(inventory)
        contents[tree[TREE_ID]] = row
        row += 1
    end
    return contents
end

@doc """
    update_infestation_years(inventory, func)

# Arguments
-`inventory::DataFrame`: Tree inventory

-`func::Function`: Function that takes the tree inventory as an input
and return a boolean array indicating whether the tree is dead. The tree
status is then updated to dead.
"""
function update_infestation_years(inventory::DataFrame, func)
    infested = inventory[TREE_LARVAE_CUMUL] .> 0
    inventory[infested, TREE_YEARS_INFEST] += fill(1, count(infested))

    dead = func(inventory)
    inventory[dead, TREE_STATUS] = fill(TREE_STATUS_DICT["D"], count(dead))
    return inventory
end

# ==================================================
# ==================================================
@doc """
    estimate_surface_area(inventory, func)

Estimates the surface area on the tree using func,
which takes the DBH (diameter at breast height) as input.

# Arguments
-`inventory::DataFrame`: Tree inventory

-`func::Function`: Function that predicts the surface area
given the DBH
"""
function estimate_surface_area(inventory::DataFrame, func)
    inventory[TREE_SURFACE_AREA] = func.(inventory[TREE_DBH]);
    return inventory
end

@doc """
    unit_conversion(inventory, column, factor)

Updates values in `inventory`[`column`] through multiplication by `factor`

# Arguments
-`inventory::DataFrame`: Tree inventory

-`column::Symbol`: Column designation to apply the multiplication operation

-`factor::Number`: Multiplication factor to apply
"""
function unit_conversion(inventory::DataFrame, column::Symbol, factor::Number)
    inventory[column] *= factor;
    return inventory
end

# ==================================================
# Functions outside a tree's characteristics
# ==================================================
@doc """
    get_distance(inventory, X, Y)

Returns the distance of the trees in `inventory` from the
position (`X`, `Y`).

# Arguments
-`inventory::DataFrame`: Tree inventory

-`X::Number`: X coordinate of position

-`Y::Number`: Y coordinate of position
"""
function get_distance(inventory::DataFrame, X::Number, Y::Number)
    return sqrt.((inventory[TREE_X] .- X).^2 .+ (inventory[TREE_Y] .- Y).^2);
end


end
