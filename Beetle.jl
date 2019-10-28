module Beetle
using DataFrames
using Namespace
using Random

@doc """
    get_adult_population(tree, census)

Returns the number of alive female beetles locatated
on a given tree, `tree`.

# Arguments
-`tree::Number`: Tree number to consider

-`census::DataFrame`: Female beetle census
"""
function get_adult_population(tree::Number, census::DataFrame)
    adult   = (census[BEETLE_STATUS] .!= BEETLE_STATUS_DICT[0]) .& (census[BEETLE_STATUS] .!= BEETLE_STATUS_DICT["D"])
    on_tree = census[BEETLE_LOCATION] .== tree
    return sum(adult .& on_tree)
end

@doc """
    get_beetle_status(census)

Updates the beetle census to reflect the status of the beetle
based on its age. Ages are set in `BEETLE_AGE_DICT` in `Namespace.jl`

# Arguments
-`census::DataFrame`: Female beetle census
"""
function get_beetle_status(census::DataFrame)
    F = BEETLE_AGE_DICT["F"] .<= census[BEETLE_AGE] .< BEETLE_AGE_DICT["M"];
    M = BEETLE_AGE_DICT["M"] .<= census[BEETLE_AGE] .< BEETLE_AGE_DICT["R"];
    R = BEETLE_AGE_DICT["R"] .<= census[BEETLE_AGE] .< BEETLE_AGE_DICT["D"];
    D = BEETLE_AGE_DICT["D"] .<= census[BEETLE_AGE];
    census[BEETLE_STATUS][F] = fill(BEETLE_STATUS_DICT["F"], count(F));
    census[BEETLE_STATUS][M] = fill(BEETLE_STATUS_DICT["M"], count(M));
    census[BEETLE_STATUS][R] = fill(BEETLE_STATUS_DICT["R"], count(R));
    census[BEETLE_STATUS][D] = fill(BEETLE_STATUS_DICT["D"], count(D));
    return census
end

@doc """
    get_occupied_trees(census)

Returns the tree numbers that have a beetle associated with it.
Note that it doesn't distinguish whether the beetle is active,
pupating, or dead.

# Arguments
-`census::DataFrame`: Female beetle census
"""
function get_occupied_trees(census::DataFrame)
    return collect(Set(census[BEETLE_LOCATION]))
end

@doc """
    increment_age(census)

Updates the beetle age by 1 day.

# Arguments
-`census::DataFrame`: Female beetle census
"""
function increment_age(census::DataFrame)
    census[BEETLE_AGE] .+= 1;
    return get_beetle_status(census)
end

@doc """
    female_emergence(inventory, directory, func)


"""
function female_emergence(inventory::DataFrame, directory, func)

    # ================================================
    # Find the infested trees
    # ================================================
    infested = inventory[inventory[TREE_LARVAE] .> 0, :];

    # ================================================
    # Create an instance for each female adult that
    # emerges from the tree - (1/2) larvae --> male
    # ================================================
    location = Int[];
    for row in eachrow(infested)

        # ============================================
        # Determine the number of females
        # ============================================
        females = count(Random.rand(Bool, row[TREE_LARVAE]))

        # ============================================
        # Add <females> instances of the tree to the
        # array <location>
        # ============================================
        append!(location, repeat([directory[row[TREE_ID]]], females));
    end

    # ================================================
    # Generate ages for each female. Negative values
    # would indicate how many days until emergence
    # ================================================
    age = func(length(location));
    all(age .<= 0) || error("<func> must return non-positive values")

    # ================================================
    # Create a data frame of the females and return
    # ================================================
    census = DataFrame();
    census[BEETLE_LOCATION] = location;
    census[BEETLE_AGE]      = age;
    census[BEETLE_STATUS]   = BEETLE_STATUS_DICT[0];

    # ================================================
    # Add the exited larave to the total
    # ================================================
    inventory[TREE_LARVAE_EMERG] .+= inventory[TREE_LARVAE];

    # ================================================
    # Set the larval counts to zero
    # ================================================
    inventory[TREE_LARVAE] = 0;

    return inventory, census
end



function deposit_eggs(inventory::DataFrame, census::DataFrame, func)

    # ==============================================
    # Select the trees where females are present
    # ==============================================
    trees = get_occupied_trees(census)

    # ==============================================
    # Count the number of reproducing females on the
    # tree and randomly generate an egg production
    # for each; add to the larvae count
    # ==============================================
    for tree in trees
        reprod = (census[BEETLE_LOCATION] .== tree) .& (census[BEETLE_STATUS] .== BEETLE_STATUS_DICT["R"])

        if count(reprod) > 0
            eggs = sum(func(count(reprod)))
            inventory[tree, TREE_LARVAE] += eggs
            inventory[tree, TREE_LARVAE_CUMUL] += eggs
        end
    end

    return inventory
end

function disperse_beetles(inventory::DataFrame, census::DataFrame, f_func, r_func)
    # ==============================================
    # Select the trees where females are present
    # ==============================================
    trees = get_occupied_trees(census)

    for tree in trees
        forage = (census[BEETLE_LOCATION] .== tree) .& (census[BEETLE_STATUS] .== BEETLE_STATUS_DICT["F"])
        reprod = (census[BEETLE_LOCATION] .== tree) .& (census[BEETLE_STATUS] .== BEETLE_STATUS_DICT["R"])

        # ==============================================
        # Update the location of the foraging beetles
        # ==============================================
        if count(forage) > 0
            new_forage_trees = f_func(tree, inventory, count(forage))
            census[forage, BEETLE_LOCATION] = new_forage_trees
        end

        # ==============================================
        # Update the location of the foraging reproducing
        # ==============================================
        if count(reprod) > 0
            new_reprod_trees = r_func(tree, inventory, count(reprod))
            census[reprod, BEETLE_LOCATION] = new_reprod_trees
        end
    end

    return census
end





end
