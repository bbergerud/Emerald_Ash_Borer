module Larvae
using DataFrames
using Namespace

# =======================================================================
# Function for initializing an infestation
# =======================================================================

@doc """
    initial_infestation(inventory, infected_trees, larvae_counts)

# Arguments
-`inventory::DataFrame`: Tree inventory

-`infected_trees::Array{Int}`: Array of integers containing the IDs of the trees

-`larvae_counts::Array{Int}`: Array of integers containing the number of larvae on the trees
"""
function initial_infestation(inventory::DataFrame, infected_trees::Array{Int}, larvae_counts::Array{Int})
    for (id,count) in zip(infected_trees, larvae_counts)
        inventory[id, TREE_LARVAE] = count
        inventory[id, TREE_LARVAE_CUMUL] = count
    end
    return inventory
end


# =======================================================================
# Functions associated with larval death
# =======================================================================

@doc """
    larvae_death_random(inventory, func)

Generate a random number of larvae deaths for infested trees
based on a random death factor generator.

# Arguments
-`inventory::DataFrame`: DataFrame containing the tree inventory

-`func::Function`: Function that takes an integer number of counts <n>
                   and returns <n> random death rates (0 <= x <= 1)
"""
function larvae_death_random(inventory::DataFrame, func)
    has_larvae  = inventory[TREE_LARVAE] .> 0
    death_rate  = func(count(has_larvae))
    death_count = trunc.(Int, round.(death_rate .* inventory[has_larvae, TREE_LARVAE]))

    inventory[has_larvae, TREE_LARVAE] -= death_count

    return inventory
end

@doc """
    larvae_death_deterministic(inventory, func)

Applies a deterministic death rate to the tree larvae
based on the function `func`. The number of tree larvae
is updated in the inventory.

# Arguments
-`inventory::DataFrame`: Tree inventory

-`func::Function`: Function that takes a tree inventory
and returns a death rate. The tree inventory is a subset of
`inventory` containing only the trees with larvae present
"""
function larvae_death_deterministic(inventory::DataFrame, func)
    has_larvae  = inventory[TREE_LARVAE] .> 0
    death_rate  = func(inventory[has_larvae,:])
    death_count = trunc.(Int, round.(death_rate .* inventory[has_larvae, TREE_LARVAE]))

    inventory[has_larvae, TREE_LARVAE] -= death_count
    return inventory
end


end
