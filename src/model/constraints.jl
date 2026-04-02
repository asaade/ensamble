module Constraints


export constraint_items_per_form,
    constraint_item_count,
    constraint_score_sum,
    constraint_item_sum,
    constraint_friends_in_form,
    constraint_enemies,
    constraint_exclude_items,
    constraint_add_anchor!,
    constraint_max_use,
    constraint_forms_overlap,
    constraint_forms_overlap2, # Warning: Experimental
    objective_match_characteristic_curve!,
    objective_match_information_curve!,
    objective_max_info,
    constraint_fix_items,
    objective_match_variance!

using DataFrames
using JuMP
using ..Configuration
using ..Utils


# ---------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------

"""
    operational_forms(x::AbstractMatrix, shadow_test_size::Int)::Int

Calculate the number of operational forms in the decision variable matrix `x`, adjusting for th size of the shadow test.

# Arguments

  - `x`: The decision variable matrix where rows correspond to items and columns to forms.
  - `shadow_test_size`: The number of shadow tests included. If greater than zero, the last column(s) are shadow tests.

# Returns

  - The number of operational (non-shadow) forms.
"""
function operational_forms(x, shadow_test_size::Int)
    forms = size(x, 2)
    return shadow_test_size > 0 ? forms - 1 : forms
end

"""
    group_by_selected(selected::AbstractVector)

Group items based on the `selected` items vector, ignoring missing values.

# Arguments

  - `selected`: A vector indicating group assignments or selection criteria for items.

# Returns

  - A `Vector{Vector{Int}}` where each sub-vector contains the indices of items in the same group.

# Notes

  - Missing values and items not satisfying the selection criteria are excluded.
"""
function group_by_selected(selected::AbstractVector)
    groups = Dict{Any, Vector{Int}}()
    for (i, val) in enumerate(selected)
        if ismissing(val) || val === false || (val isa Number && val <= 0)
            continue
        end
        push!(get!(groups, val, Int[]), i)
    end
    return [groups[k] for k in sort(collect(keys(groups)))]
end

# ---------------------------------------------------------------------------
# Constraint Functions for item counts
# ---------------------------------------------------------------------------

"""
    constraint_items_per_form(
        model::Model,
        parms::Parameters,
        minItems::Int,
        maxItems::Int = minItems
    )::Model

Ensure each operational form contains between `minItems` and `maxItems` items.

# Arguments

  - `model`: The JuMP model to which the constraints are added.
  - `parms`: Parameters containing the item bank and settings.
  - `minItems`: Minimum number of items required in each form.
  - `maxItems`: Maximum number of items allowed in each form (defaults to `minItems`).

# Returns

  - The updated `Model` with the new constraints.
"""
function constraint_items_per_form(
    model::Model, parms::Parameters, minItems::Int, maxItems::Int=minItems
)
    return constraint_item_count(
        model, parms, trues(size(parms.bank, 1)), minItems, maxItems
    )
end

"""
    constraint_item_count(
        model::Model,
        parms::Parameters,
        selected::AbstractVector,
        minItems::Int,
        maxItems::Int = minItems
    )::Model

Ensure the number of selected items falls within specified bounds in each form.

# Arguments

  - `model`: The JuMP model to which the constraints are added.
  - `parms`: Parameters containing the item bank and settings.
  - `selected`: Boolean vector indicating which items to include.
  - `minItems`: Minimum number of selected items required in each form.
  - `maxItems`: Maximum number of selected items allowed in each form (defaults to `minItems`).

# Returns

  - The updated `Model` with the new constraints.
"""
function constraint_item_count(model::Model, parms::Parameters, selected::AbstractVector,
    minItems::Int, maxItems::Int=minItems)
    @assert(minItems <= maxItems, "maxItems < minItems")

    x = model[:x]
    items = findall(selected)
    forms = operational_forms(x, parms.shadow_test_size)

    @constraint(model, [f = 1:forms], minItems <= sum(x[items, f]) <= maxItems)

    if parms.shadow_test_size > 0
        shadow_test_col = size(x, 2)

        # Use .! for broadcasting NOT over the BitVector returned by ismissing.()
        is_anchor = .!ismissing.(parms.bank.ANCHOR[items])

        anchor_count = sum(is_anchor)
        non_anchor_items = items[.!is_anchor]

        eff_min = max(0, minItems - anchor_count) * parms.shadow_test_size
        eff_max = max(0, maxItems - anchor_count) * parms.shadow_test_size

        @constraint(model, eff_min <= sum(x[non_anchor_items, shadow_test_col]) <= eff_max)
    end

    return model
end

"""
    constraint_score_sum(
        model::Model,
        parms::Parameters,
        selected::AbstractVector,
        minScore::Int64,
        maxScore::Int64 = minScore
    )::Model

Ensure the sum of selected item scores is within `minScore` and `maxScore` for each form.

# Arguments

  - `model`: The JuMP model to which the constraints are added.
  - `parms`: Parameters containing the item bank and settings.
  - `selected`: Boolean vector indicating which items to include.
  - `minScore`: Minimum total score required for the selected items.
  - `maxScore`: Maximum total score allowed (defaults to `minScore`).

# Returns

  - The updated `Model` with the new constraints.
"""
function constraint_score_sum(model::Model, parms::Parameters, selected::AbstractVector, minScore::Int64, maxScore::Int64=minScore)
    @assert(minScore <= maxScore, "Error in item_score_sum: maxScore < minScore")

    x = model[:x]
    items = findall(selected)
    forms = operational_forms(x, parms.shadow_test_size)

    # Use a direct mapping to avoid indexing mismatches
    # Assumes NUM_CATEGORIES exists in parms.bank
    item_scores = Dict(i => parms.bank.NUM_CATEGORIES[i] - 1 for i in items)

    # Constraints for operational forms
    for f in 1:forms
        @constraint(model, sum(x[i, f] * item_scores[i] for i in items) >= minScore)
        @constraint(model, sum(x[i, f] * item_scores[i] for i in items) <= maxScore)
    end

    # Shadow test constraints
    if parms.shadow_test_size > 0
        shadow_test_col = size(x, 2)

        # Identify anchors within the selected set
        is_anchor = [!ismissing(parms.bank.ANCHOR[i]) for i in items]
        anchor_items = items[is_anchor]
        non_anchor_items = items[.!is_anchor]

        # Calculate fixed score contribution from anchors
        anchor_score_sum = sum(item_scores[i] for i in anchor_items; init=0)

        eff_min = max(0, minScore - anchor_score_sum) * parms.shadow_test_size
        eff_max = max(0, maxScore - anchor_score_sum) * parms.shadow_test_size

        @constraint(model, sum(x[i, shadow_test_col] * item_scores[i] for i in non_anchor_items) >= eff_min)
        @constraint(model, sum(x[i, shadow_test_col] * item_scores[i] for i in non_anchor_items) <= eff_max)
    end

    return model
end

# ---------------------------------------------------------------------------
# Constraint Functions for item value sums
# ---------------------------------------------------------------------------

"""
    constraint_item_sum(
        model::Model,
        parms::Parameters,
        vals,
        minVal::Real,
        maxVal::Real = minVal
    )::Model

Ensure the sum of item values is within specified bounds for each form.

# Arguments

  - `model`: The JuMP model to which the constraints are added.
  - `parms`: Parameters containing the item bank and settings.
  - `vals`: A vector or matrix of item values (and optionally conditions).
  - `minVal`: Minimum total value required.
  - `maxVal`: Maximum total value allowed (defaults to `minVal`).

# Returns

  - The updated `Model` with the new constraints.
"""
function constraint_item_sum(model::Model, parms::Parameters, vals, minVal, maxVal=minVal)
    @assert(minVal <= maxVal, "Error in item_sum: maxVal < minVal")

    x = model[:x]
    n_items = size(x, 1)
    forms = operational_forms(x, parms.shadow_test_size)

    # Standardize val and condition
    val = ndims(vals) == 1 ? vals : vals[:, 2]
    cond = ndims(vals) == 1 ? trues(length(vals)) : vals[:, 1]

    # Pre-filter indices satisfying the condition to optimize summation
    active_indices = findall(cond)

    # Constraints for operational forms
    for f in 1:forms
        @constraint(model, minVal <= sum(x[i, f] * val[i] for i in active_indices) <= maxVal)
    end

    # Shadow test constraints
    if parms.shadow_test_size > 0
        shadow_test_col = size(x, 2)

        # Identify anchors within the active set
        # is_anchor is a BitVector; use .! for broadcasted negation
        is_anchor = .!ismissing.(parms.bank.ANCHOR)

        # Intersection of items meeting the condition and being anchors/non-anchors
        anchor_indices = [i for i in active_indices if is_anchor[i]]
        non_anchor_indices = [i for i in active_indices if !is_anchor[i]]

        # Fixed contribution from anchors satisfying the condition
        anchor_val_sum = sum(val[i] for i in anchor_indices; init=0.0)

        eff_min = max(0.0, minVal - anchor_val_sum) * parms.shadow_test_size
        eff_max = max(0.0, maxVal - anchor_val_sum) * parms.shadow_test_size

        @constraint(model,
            eff_min <= sum(x[i, shadow_test_col] * val[i] for i in non_anchor_indices) <= eff_max
        )
    end

    return model
end

# ---------------------------------------------------------------------------
# Constraint Functions for item groups (friends, enemies, anchors)
# ---------------------------------------------------------------------------

"""
    constraint_friends_in_form(
        model::Model,
        parms::Parameters,
        selected::AbstractVector
    )::Model

Ensure that friend items are assigned to the same form.

# Arguments

  - `model`: The JuMP model to which the constraints are added.
  - `parms`: Parameters containing the item bank and settings.
  - `selected`: Vector indicating groups of friend items.

# Returns

  - The updated `Model` with the new constraints.
"""
function constraint_friends_in_form(model::Model, parms::Parameters, selected::AbstractVector)
    x = model[:x]
    # Friends must stay together in operational forms AND the shadow reservoir
    total_cols = size(x, 2)
    groups = group_by_selected(selected)

    for items in groups
        cnt = length(items)
        if cnt > 1
            pivot = items[1]
            # If the pivot item is selected (1), all items in group must be 1
            @constraint(model, [f = 1:total_cols],
                sum(x[i, f] for i in items) == (cnt * x[pivot, f]))
        end
    end
    return model
end

"""
    constraint_enemies(
        model::Model,
        parms::Parameters,
        selected::AbstractVector
    )::Model

Ensure that only one of a group of enemy items is assigned to the same form.

# Arguments

  - `model`: The JuMP model to which the constraints are added.
  - `parms`: Parameters containing the item bank and settings.
  - `selected`: Vector indicating groups of enemy items.

# Returns

  - The updated `Model` with the new constraints.
"""
function constraint_enemies(model::Model, parms::Parameters, selected::AbstractVector)
    x = model[:x]
    # Enemies are only restricted in operational forms (1:forms)
    # The shadow test column (reservoir) may contain multiple enemies for future use
    forms = operational_forms(x, parms.shadow_test_size)

    groups = if eltype(selected) <: Union{Bool, Missing}
        [findall(s -> isequal(s, true), selected)]
    else
        group_by_selected(selected)
    end

    for items in groups
        if length(items) > 1
            @constraint(model, [f = 1:forms], sum(x[i, f] for i in items) <= 1)
        end
    end
    return model
end

"""
    constraint_exclude_items(
        model::Model,
        exclude::AbstractVector
    )::Model

Exclude specified items from being selected in any form.

# Arguments

  - `model`: The JuMP model to which the constraints are added.
  - `exclude`: Boolean vector indicating items to exclude (`true` to exclude).

# Returns

  - The updated `Model` with the items fixed to 0.
"""
function constraint_exclude_items(model::Model, exclude::AbstractVector)
    x = model[:x]
    items = findall(exclude)
    total_cols = size(x, 2)

    for i in items, f in 1:total_cols
        JuMP.fix(x[i, f], 0; force=true)
    end
    return model
end

"""
    constraint_fix_items(
        model::Model,
        fixed::AbstractVector
    )::Model

Force certain items to be included in every form.

# Arguments

  - `model`: The JuMP model to which the constraints are added.
  - `fixed`: Boolean vector indicating items to include (`true` to include).

# Returns

  - The updated `Model` with the items fixed to 1.
"""
function constraint_fix_items(model::Model, fixed::AbstractVector)
    x = model[:x]
    items = findall(fixed)
    total_cols = size(x, 2)

    for i in items, f in 1:total_cols
        JuMP.fix(x[i, f], 1; force=true)
    end
    return model
end

"""
    constraint_add_anchor!(
        model::Model,
        parms::Parameters
    )::Model

Ensure anchor items are included in all operational forms, ignoring shadow forms.

# Arguments

  - `model`: The JuMP model to which the constraints are added.
  - `parms`: Parameters containing the item bank and settings.

# Returns

  - The updated `Model` with anchor items fixed to 1.
"""
function constraint_add_anchor!(model::Model, parms::Parameters)
    if parms.anchor_tests > 0
        x = model[:x]
        # Anchors are fixed in operational forms only
        forms = operational_forms(x, parms.shadow_test_size)
        anchor_items = findall(.!ismissing.(parms.bank.ANCHOR))

        for i in anchor_items, f in 1:forms
            JuMP.fix(x[i, f], 1; force=true)
        end
    end
    return model
end

# ---------------------------------------------------------------------------
# Constraint Functions for item sharing between forms
# ---------------------------------------------------------------------------

"""
    constraint_max_use(
        model::Model,
        parms::Parameters,
        selected::AbstractVector
    )::Model

Constrain the maximum number of times an item can appear across the test forms.

# Arguments

  - `model`: The JuMP model to which the constraints are added.
  - `parms`: Parameters containing the item bank and settings.
  - `selected`: Boolean vector indicating items subject to the constraint.

# Returns

  - The updated `Model` with the new constraints.
"""
function constraint_max_use(model::Model, parms::Parameters, selected::AbstractVector)
    x = model[:x]
    forms = operational_forms(x, parms.shadow_test_size)
    n_max = parms.max_item_use

    selected_indices = findall(selected)
    is_not_anchor = ismissing.(parms.bank.ANCHOR)
    target_items = [i for i in selected_indices if is_not_anchor[i]]

    if !isempty(target_items)
        @constraint(model, usage_limit[i in target_items],
            sum(x[i, f] for f in 1:forms) + coalesce(parms.bank.ITEM_USE[i], 0) <= n_max
        )
    end
    return model
end

"""
    constraint_forms_overlap(
        model::Model,
        parms::Parameters,
        minItems::Int,
        maxItems::Int = minItems
    )::Model

Constrain the number of overlapping (repeated) items between test forms.

# Arguments

  - `model`: The JuMP model to which the constraints are added.
  - `parms`: Parameters containing the item bank and settings.
  - `minItems`: Minimum number of items that must overlap between any two forms.
  - `maxItems`: Maximum number of items that can overlap (defaults to `minItems`).

# Returns

  - The updated `Model` with the new constraints.
"""
function constraint_forms_overlap(model::Model, parms::Parameters, minItems::Int, maxItems::Int=minItems)
    @assert(0 <= minItems <= maxItems, "forms_overlap: maxItems < minItems")

    x = model[:x]
    n_items, n_cols = size(x)
    n_forms = operational_forms(x, parms.shadow_test_size)

    # Standard Pairwise Overlap (No Shadow Test)
    if parms.shadow_test_size == 0
        if !haskey(object_dictionary(model), :z)
            @variable(model, z[1:n_items, 1:n_forms, 1:n_forms], Bin)
        end
        z = model[:z]

        for t1 in 1:(n_forms-1), t2 in (t1+1):n_forms
            @constraint(model, minItems <= sum(z[i, t1, t2] for i in 1:n_items) <= maxItems)

            for i in 1:n_items
                @constraint(model, z[i, t1, t2] <= x[i, t1])
                @constraint(model, z[i, t1, t2] <= x[i, t2])
                @constraint(model, z[i, t1, t2] >= x[i, t1] + x[i, t2] - 1)
            end
        end

    # Shadow Test Overlap (Reservoir Logic)
    elseif parms.shadow_test_size > 0
        shadow_col = n_cols
        if !haskey(object_dictionary(model), :w)
            @variable(model, w[1:n_items, 1:n_forms], Bin)
        end
        w = model[:w]

        # Shadow test size acts as the multiplier for future-form availability
        eff_min = minItems * parms.shadow_test_size
        eff_max = maxItems * parms.shadow_test_size

        for f in 1:n_forms
            @constraint(model, eff_min <= sum(w[i, f] for i in 1:n_items) <= eff_max)

            for i in 1:n_items
                @constraint(model, w[i, f] <= x[i, f])
                @constraint(model, w[i, f] <= x[i, shadow_col])
                @constraint(model, w[i, f] >= x[i, f] + x[i, shadow_col] - 1)
            end
        end
    end
    return model
end


# ---------------------------------------------------------------------------
# Objective Functions for Test Assembly Optimization
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Note: Anchor Tests are designed to appear repeatedly, bounded in sets that alternate between forms. This behaviour
# imposes the need of a special treatment, different to the one used with regular items. In order
# to use this combined with the Shadow Test method, our solution was to calculate the contribution of these special
# items to the target variables and use the result as a proxy for other sets of anchor items in subsequent forms.
# This special treatment has made the code more complex in most cases.
# ---------------------------------------------------------------------------


"""
    objective_match_characteristic_curve!(
        model::Model,
        parms::Parameters
    )::Model

Match test characteristic curves to target values. Following the suggestion
of Wim van der Linden, the curves are also compared with their powers 1..R.
for a closer match. (in the book'Linear models for Optimal Test Testing')

# Arguments

  - `model`: The JuMP model containing decision variables `x` and `y`.
  - `parms`: Parameters containing target curves and item probabilities.

# Returns

  - The updated `Model` with the new constraints.
"""
function objective_match_characteristic_curve!(model::Model, parms::Parameters)
    @assert haskey(model, :x) && haskey(model, :y) "Model requires x and y"

    R_range, K_range = 1:(parms.r), 1:(parms.k)
    P, tau = parms.score_matrix, parms.tau
    x, y = model[:x], model[:y]

    n_items = size(x, 1)
    n_forms = operational_forms(x, parms.shadow_test_size)
    w = [1.1 - 0.1 * r for r in R_range]

    is_anchor = .!ismissing.(parms.bank.ANCHOR)
    anchor_indices = findall(is_anchor)
    non_anchor_indices = findall(.!is_anchor)

    anchor_contribution = zeros(Float64, length(R_range), length(K_range))
    if parms.anchor_tests > 0
        for k in K_range, r in R_range
            anchor_contribution[r, k] = sum(P[i, k]^r for i in anchor_indices; init=0.0)
        end
    end

    # Operational Forms: Split into two constraints to handle variable 'y'
    @constraint(model, tcc_upper[f=1:n_forms, k=K_range, r=R_range],
        sum(P[i, k]^r * x[i, f] for i in 1:n_items) <= tau[r, k] + w[r] * y)
    @constraint(model, tcc_lower[f=1:n_forms, k=K_range, r=R_range],
        sum(P[i, k]^r * x[i, f] for i in 1:n_items) >= tau[r, k] - w[r] * y)

    # Shadow Test Reservoir: Scaled constraints
    if parms.shadow_test_size > 0
        zcol = size(x, 2)
        S = parms.shadow_test_size
        @constraint(model, shadow_tcc_upper[k=K_range, r=R_range],
            sum(P[i, k]^r * x[i, zcol] for i in non_anchor_indices) <= (tau[r, k] - anchor_contribution[r, k] + w[r] * y) * S)
        @constraint(model, shadow_tcc_lower[k=K_range, r=R_range],
            sum(P[i, k]^r * x[i, zcol] for i in non_anchor_indices) >= (tau[r, k] - anchor_contribution[r, k] - w[r] * y) * S)
    end

    return model
end

"""
    objective_match_variance!(
        model::Model,
        parms::Parameters,
        β::Float64 = 1.0
    )::Model

Incorporate variance matching into the objective function to ensure that assembled test forms match the variance of expected scores at selected theta points.

# Arguments

  - `model`: The JuMP model containing decision variables `x` and potentially an existing objective.
  - `parms`: Parameters containing expected scores and variances.
  - `β`: Weight factor for variance matching in the objective function (default: 1.0).

# Returns

  - The updated `Model` with the new variables, constraints, and updated objective function.
"""
function objective_match_variance!(model::Model, parms::Parameters, β::Float64 = 1.0)
    # Validate inputs
    @assert β > 0 "Weight factor β must be positive"

    # Extract parameters
    K = 1:parms.k                  # Theta points
    items_mean_score = parms.items_mean_score  # Mean expected scores at each theta point
    expected_scores = parms.score_matrix       # Expected scores matrix (items x theta points)
    x = model[:x]                  # Decision variables matrix (items x forms)
    num_items, num_forms_total = size(x)

    # Handle shadow test configuration
    has_shadow_test = parms.shadow_test_size > 0
    num_forms = has_shadow_test ? num_forms_total - 1 : num_forms_total
    shadow_test_col = has_shadow_test ? num_forms_total : nothing

    # Separate anchor and non-anchor items
    if parms.anchor_tests > 0
        anchor_items = [i for i in 1:num_items if !ismissing(parms.bank.ANCHOR[i])]
    else
        anchor_items = Int[]
    end
    non_anchor_items = setdiff(1:num_items, anchor_items)

    # Compute target variance at each theta point
    target_variance = zeros(length(K))
    for (idx_k, k) in enumerate(K)
        μ_k = items_mean_score[k]
        deviations = expected_scores[:, k] .- μ_k
        target_variance[idx_k] = sum(deviations .^ 2)
    end

    # Compute anchor items' variance contribution
    anchor_variance_contribution = zeros(length(K))
    if !isempty(anchor_items)
        for (idx_k, k) in enumerate(K)
            μ_k = items_mean_score[k]
            deviations = expected_scores[anchor_items, k] .- μ_k
            anchor_variance_contribution[idx_k] = sum(deviations .^ 2)
        end
    end

    # Effective target variance for non-anchor items
    effective_target_variance = target_variance .- anchor_variance_contribution

    # Define deviation variables for variance matching
    @variable(model, δ[1:num_forms, 1:length(K)] >= 0)

    # Add variance expressions for each operational form
    @expression(model, variance_selected[f=1:num_forms, idx_k=1:length(K)],
        sum((expected_scores[i, K[idx_k]] - items_mean_score[K[idx_k]])^2 * x[i, f] for i in non_anchor_items)
    )

    # Deviation constraints for variance matching
    @constraint(model, [f=1:num_forms, idx_k=1:length(K)],
        δ[f, idx_k] >= variance_selected[f, idx_k] - effective_target_variance[idx_k]
    )
    @constraint(model, [f=1:num_forms, idx_k=1:length(K)],
        δ[f, idx_k] >= effective_target_variance[idx_k] - variance_selected[f, idx_k]
    )

    # For the shadow test (if applicable)
    if has_shadow_test
        f = shadow_test_col
        # Define deviation variables for the shadow test
        @variable(model, δ_shadow[1:length(K)] >= 0)

        # Variance expressions for the shadow test
        @expression(model, shadow_variance_selected[idx_k=1:length(K)],
            sum((expected_scores[i, K[idx_k]] - items_mean_score[K[idx_k]])^2 * x[i, f] for i in non_anchor_items)
        )

        # Deviation constraints for the shadow test
        @constraint(model, [idx_k=1:length(K)],
            δ_shadow[idx_k] >= shadow_variance_selected[idx_k] - effective_target_variance[idx_k]
        )
        @constraint(model, [idx_k=1:length(K)],
            δ_shadow[idx_k] >= effective_target_variance[idx_k] - shadow_variance_selected[idx_k]
        )
    end

    # Update the objective function
    # Check if an objective function already exists
    if JuMP.objective_function(model) !== nothing
        # Get the existing objective sense (Min or Max)
        sense = JuMP.objective_sense(model)
        existing_objective = JuMP.objective_function(model)
        # Add variance deviation terms to the existing objective
        if has_shadow_test
            total_variance_deviation = sum(δ) + sum(δ_shadow)
        else
            total_variance_deviation = sum(δ)
        end
        # Update the objective function
        @objective(model, sense, existing_objective + β * total_variance_deviation)
    else
        # No existing objective, set a new one
        if has_shadow_test
            total_variance_deviation = sum(δ) + sum(δ_shadow)
        else
            total_variance_deviation = sum(δ)
        end
        # Set the objective to minimize total variance deviation
        @objective(model, Min, β * total_variance_deviation)
    end

    return model
end


"""
    objective_match_information_curve!(
        model::Model,
        parms::Parameters
    )::Model

Match information curves to target values at each theta point.

# Arguments

  - `model`: The JuMP model containing decision variables `x` and `y`.
  - `parms`: Parameters containing item information and target values.

# Returns

  - The updated `Model` with the new constraints.
"""
function objective_match_information_curve!(model::Model, parms::Parameters)
    K_range, info, tau_info = 1:parms.k, parms.info_matrix, parms.tau_info
    x, y = model[:x], model[:y]

    n_items = size(x, 1)
    n_forms = operational_forms(x, parms.shadow_test_size)
    alpha = (parms.method == "MIXED") ? 1.0 : 0.5

    is_anchor = .!ismissing.(parms.bank.ANCHOR)
    anchor_indices = findall(is_anchor)
    non_anchor_indices = findall(.!is_anchor)

    anchor_info_cont = [sum(info[i, k] for i in anchor_indices; init=0.0) for k in K_range]

    # Operational Forms
    @constraint(model, info_upper[f=1:n_forms, k=K_range],
        sum(info[i, k] * x[i, f] for i in 1:n_items) <= tau_info[k] + y * alpha)
    @constraint(model, info_lower[f=1:n_forms, k=K_range],
        sum(info[i, k] * x[i, f] for i in 1:n_items) >= tau_info[k] - y * alpha)

    # Shadow Test Reservoir
    if parms.shadow_test_size > 0
        zcol = size(x, 2)
        S = parms.shadow_test_size
        @constraint(model, shadow_info_upper[k=K_range],
            sum(info[i, k] * x[i, zcol] for i in non_anchor_indices) <= (tau_info[k] - anchor_info_cont[k] + y * alpha) * S)
        @constraint(model, shadow_info_lower[k=K_range],
            sum(info[i, k] * x[i, zcol] for i in non_anchor_indices) >= (tau_info[k] - anchor_info_cont[k] - y * alpha) * S)
    end

    return model
end

"""
    objective_info_relative(
        model::Model,
        parms::Parameters
    )::Model

Maximize information at alternating theta points across forms.

# Arguments

  - `model`: The JuMP model containing decision variables `x` and `y`.
  - `parms`: Parameters containing weights and item information.

# Returns

  - The updated `Model` with the new constraints.
"""
function objective_info_relative(model::Model, parms::Parameters)
    R = parms.relative_target_weights
    K_range = 1:length(R)
    info = parms.info_matrix
    x, y = model[:x], model[:y]

    n_items = size(x, 1)
    n_forms = operational_forms(x, parms.shadow_test_size)

    is_anchor = .!ismissing.(parms.bank.ANCHOR)
    anchor_indices = findall(is_anchor)
    non_anchor_indices = findall(.!is_anchor)

    anchor_info_cont = [sum(info[i, k] for i in anchor_indices; init=0.0) for k in K_range]

    # Operational Forms: Maximize information at rotating theta points
    for f in 1:n_forms
        k_idx = (f - 1) % length(K_range) + 1
        @constraint(model, sum(info[i, k_idx] * x[i, f] for i in 1:n_items) >= R[k_idx] * y + anchor_info_cont[k_idx])
    end

    # Shadow Test Reservoir: Ensure the pool can support all future rotations
    if parms.shadow_test_size > 0
        zcol = size(x, 2)
        S = parms.shadow_test_size
        # The reservoir should hold a cumulative amount of info for all theta points
        # to ensure future feasibility for any rotation index.
        for k in K_range
            @constraint(model, sum(info[i, k] * x[i, zcol] for i in non_anchor_indices) >= (R[k] * y) * S)
        end
    end

    return model
end

"""
    objective_max_info(
        model::Model,
        parms::Parameters
    )::Model

Maximize information at each theta point, meeting a weighted target.

# Arguments

  - `model`: The JuMP model containing decision variables `x` and `y`.
  - `parms`: Parameters containing weights and item information.

# Returns

  - The updated `Model` with the new constraints.
"""
function objective_max_info(model::Model, parms::Parameters)
    R = parms.relative_target_weights
    K_range = 1:parms.k
    info = parms.info_matrix
    x, y = model[:x], model[:y]

    n_items = size(x, 1)
    n_forms = operational_forms(x, parms.shadow_test_size)

    # Efficient index retrieval using broadcasting
    is_anchor = .!ismissing.(parms.bank.ANCHOR)
    anchor_indices = findall(is_anchor)
    non_anchor_indices = findall(.!is_anchor)

    # Pre-calculate anchor contributions for each theta point
    anchor_info_cont = [sum(info[i, k] for i in anchor_indices; init=0.0) for k in K_range]

    # Operational forms constraints
    # Sum includes all items; anchors are fixed to 1 elsewhere in the module
    for f in 1:n_forms, k in K_range
        @constraint(model, sum(info[i, k] * x[i, f] for i in 1:n_items) >= R[k] * y)
    end

    # Shadow test reservoir constraints
    if parms.shadow_test_size > 0
        S = parms.shadow_test_size
        shadow_test_col = size(x, 2)
        for k in K_range
            # Corrected logic: The reservoir must contain enough information to satisfy
            # the non-anchor portion of S future forms.
            # (Target - Anchor Contribution) * shadow_test_size
            target_non_anchor = (R[k] * y - anchor_info_cont[k]) * S
            @constraint(model,
                sum(info[i, k] * x[i, shadow_test_col] for i in non_anchor_indices) >= target_non_anchor)
        end
    end

    return model
end

end  # module Constraints
