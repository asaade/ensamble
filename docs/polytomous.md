# Polytomous

To extend the existing functions for polytomous IRT models, we need to adapt the logic to handle multiple response categories per item. The polytomous models like **Graded Response Model (GRM)**, **Partial Credit Model (PCM)**, and **Generalized Partial Credit Model (GPCM)** provide probabilities for each response category of an item, instead of a binary correct/incorrect outcome.

### General Approach for Polytomous Models:

 1. **Polytomous `lw_dist`**:
    
      + We need to modify the recursion formula to handle multiple categories for each item. The score distribution will no longer be binary but will have more levels, corresponding to the number of categories in each item.

 2. **Polytomous `observed_score`**:
    
      + Instead of summing over binary outcomes, the observed score distribution will now sum across multiple response categories for each examinee's ability level.
 3. **Polytomous `observed_score_continuous`**:
    
      + The same integration logic will be applied, but now the probability distribution will be based on multiple response categories.

### 1. **Polytomous `lw_dist` (Lord and Wingersky Recursion)**

We will modify the recursion formula to handle multiple categories for each item, similar to how it's done in the Partial Credit Model (PCM) or Graded Response Model (GRM). Each item can now contribute a score of 0 up to the number of categories minus 1.

#### Modified Code for `lw_dist`:

```julia
function lw_dist_polytomous(
        prob_matrix::Matrix{Float64}, num_categories::Vector{Int}
)::Vector{Float64}
    """
    Implementation of Lord and Wingersky Recursion Formula for polytomous items.

    # Arguments
    - `prob_matrix`: Matrix of probabilities for all categories (num_items x max_categories).
    - `num_categories`: Vector indicating the number of categories for each item.

    # Returns
    - Score distribution as a vector.
    """
    num_items = size(prob_matrix, 1)
    max_score = sum(num_categories) - num_items  # Max possible score (excluding the 0 scores)

    # Initialize the score distribution for the first item
    res = prob_matrix[1, 1:num_categories[1]]

    # Iterate through all items to build the full score distribution
    for i in 2:num_items
        num_cat = num_categories[i]
        new_res = zeros(Float64, length(res) + num_cat - 1)

        # Update the score distribution by adding the probabilities for each category
        for j in eachindex(res)
            for k in 1:num_cat
                new_res[j + k - 1] += res[j] * prob_matrix[i, k]
            end
        end
        res = new_res
    end

    return res
end
```

### Explanation:

 1. **Probability Matrix**: `prob_matrix` is a matrix where each row contains the probabilities of the different response categories for each item.
 2. **Recursion**: The function initializes the score distribution for the first item and iteratively combines the scores for each item, similar to the Lord and Wingersky recursion formula but generalized for polytomous items.
 3. **Score Distribution**: The result is a score distribution vector representing the probability of each total score from 0 to the maximum possible score.

* * *

### 2. **Polytomous `observed_score`**

This function will now sum the polytomous score distributions for a group of examinees, where each examinee is represented by an ability level \( \theta \). We will generate the probabilities for each response category and then use the polytomous Lord and Wingersky recursion formula to compute the score distribution.

#### Modified Code for `observed_score`:

```julia
function observed_score_polytomous(
        prob_matrices::Vector{Matrix{Float64}}, num_categories::Vector{Int}, num_examinees::Int
)::Vector{Float64}
    """
    Calculates the observed score distribution for polytomous items.

    # Arguments
    - `prob_matrices`: Vector of probability matrices for each examinee.
    - `num_categories`: Vector indicating the number of categories for each item.
    - `num_examinees`: Number of examinees.

    # Returns
    - The observed score distribution as a vector.
    """
    max_score = sum(num_categories) - length(num_categories)  # Max possible score
    cumulative_distribution = zeros(Float64, max_score + 1)

    for P in prob_matrices
        score_dist = lw_dist_polytomous(P, num_categories)
        cumulative_distribution .= cumulative_distribution .+ score_dist
    end

    return cumulative_distribution ./ num_examinees
end
```

### Explanation:

 1. **Probability Matrices**: The input `prob_matrices` is a vector where each element is a probability matrix for a different examinee, containing the probabilities of responding in each category for each item.
 2. **Recursion Formula**: For each examinee, we calculate the score distribution using the polytomous Lord and Wingersky recursion formula (`lw_dist_polytomous`).
 3. **Score Distribution**: The cumulative score distribution is calculated by averaging the score distributions over all examinees.

* * *

### 3. **Polytomous `observed_score_continuous`**

This function will perform numerical integration using the polytomous response model to estimate the score distribution for a continuous ability distribution, such as a normal distribution.

#### Modified Code for `observed_score_continuous`:

```julia
function observed_score_continuous_polytomous(
        prob_function::Function, ability_dist::Normal; num_points::Int = 100
)::Vector{Float64}
    """
    Calculates the observed score distribution for polytomous items using numerical integration.

    # Arguments
    - `prob_function`: A function that returns the probability matrix for a given θ.
    - `ability_dist`: Ability distribution (e.g., Normal(0, 1)).
    - `num_points`: Number of points for numerical integration.

    # Returns
    - The observed score distribution as a vector.
    """
    max_score = sum(prob_function(0)[1]) - length(prob_function(0))  # Max possible score
    observed_dist = zeros(Float64, max_score + 1)

    # Define the integrand for numerical integration
    function integrand(θ, x)
        prob_matrix = prob_function(θ)
        score_dist = lw_dist_polytomous(prob_matrix, size(prob_matrix, 2))
        return score_dist[x + 1] * pdf(ability_dist, θ)
    end

    # Perform numerical integration for each score point
    for x in 0:max_score
        observed_dist[x + 1] = quadgk(θ -> integrand(θ, x), -Inf, Inf; order = num_points)[1]
    end

    return observed_dist
end
```

### Explanation:

 1. **Probability Function**: `prob_function` is a function that, for a given ability \( \theta \), returns a probability matrix for each item, containing the probabilities for each response category.
 2. **Numerical Integration**: We integrate over the ability distribution to calculate the observed score distribution for a continuous distribution of abilities.
 3. **Score Distribution**: The final score distribution is obtained by summing the contributions of different ability levels, weighted by the probability density function (PDF) of the ability distribution.

* * *

### Conclusion:

These modified functions extend the existing dichotomous IRT models to polytomous models like GRM, PCM, and GPCM. The key difference is the handling of multiple response categories for each item. The recursion formula (`lw_dist_polytomous`) and the integration-based approach (`observed_score_continuous_polytomous`) now account for the additional complexity introduced by polytomous items, making them suitable for a wide range of testing applications where items have more than two response options.

To extend the `calc_tau` and `calc_info_tau` functions to handle polytomous models, we need to modify the approach to reflect the nature of polytomous items, where each item can have multiple response categories rather than binary outcomes. The core structure of these functions will remain the same, but the way probabilities and information are handled will be adjusted for polytomous models.

### General Approach:

 1. **`calc_tau` for Polytomous Models**:
    
      + Instead of working with dichotomous probabilities, we'll be summing over multiple categories for each item. For polytomous models like GRM, PCM, and GPCM, the probability matrix will have multiple probabilities corresponding to the different response categories for each item.
      + We need to account for the multiple categories when raising the probabilities to different powers `r`.

 2. **`calc_info_tau` for Polytomous Models**:
    
      + Similarly, the information function for polytomous items will now sum over multiple categories instead of just two outcomes. We need to make sure we calculate the total information for each item over all categories before computing the `tau` values.

### 1. **`calc_tau` for Polytomous Models**

We need to modify `calc_tau` to sum the probability values for each category of the polytomous items, at each theta point.

#### Modified Code for `calc_tau`:

```julia
function calc_tau_polytomous(P::Array{Float64, 3}, R::Int, K::Int, N::Int)::Matrix{Float64}
    """
    Calculates the tau matrix for polytomous models.

    # Arguments
    - `P`: 3D probability matrix of size (N_items, K_points, Categories). Contains probabilities for each category.
    - `R`: Number of powers.
    - `K`: Number of theta points.
    - `N`: Sample size (number of items to sample).

    # Returns
    - The tau matrix.
    """
    tau = zeros(Float64, R, K)
    N_items, _, categories = size(P)

    for _ in 1:500
        # Sample N items randomly from the probability matrix
        sampled_data = P[rand(1:N_items, N), :, :]

        for r in 1:R
            # Sum over categories for each theta point, then raise to power r
            for k in 1:K
                tau[r, k] += sum(sum(sampled_data[:, k, :] .^ r))
            end
        end
    end
    return tau / 500.0
end
```

### Explanation:

 1. **Probability Matrix**: The matrix `P` is now a 3D matrix of size `(N_items, K_points, Categories)`, where each slice along the third dimension represents the probability for each category of the polytomous items.

 2. **Sampling and Power Calculation**: We randomly sample `N` items and sum the probabilities for all categories at each theta point, raising them to power `r` as required.
 3. **Summation**: We sum over all categories and theta points for each sampled set and repeat the process 500 times, averaging the results to produce the final `tau` matrix.

* * *

### 2. **`calc_info_tau` for Polytomous Models**

For `calc_info_tau`, we also need to sum the information values across the multiple categories for each item before calculating the total information for each theta point.

#### Modified Code for `calc_info_tau`:

```julia
function calc_info_tau_polytomous(info::Array{Float64, 3}, K::Int, N::Int)::Vector{Float64}
    """
    Calculates the information tau vector for polytomous models.

    # Arguments
    - `info`: 3D information matrix of size (N_items, K_points, Categories).
    - `K`: Number of theta points.
    - `N`: Sample size (number of items to sample).

    # Returns
    - The information tau vector.
    """
    tau = zeros(Float64, K)
    N_items, _, categories = size(info)

    for _ in 1:500
        # Sample N items randomly from the information matrix
        sampled_data = info[rand(1:N_items, N), :, :]

        # Sum over categories for each theta point
        for k in 1:K
            tau[k] += sum(sum(sampled_data[:, k, :]))
        end
    end

    return tau / 500.0
end
```

### Explanation:

 1. **Information Matrix**: The `info` matrix is now a 3D matrix of size `(N_items, K_points, Categories)` where each slice along the third dimension represents the information for each category.

 2. **Sampling and Summation**: We randomly sample `N` items and sum the information values for all categories at each theta point. The total information at each theta point is computed by summing the contributions from all categories and repeating this process 500 times, averaging the results to produce the final `tau` vector.

* * *

### Conclusion:

These functions, `calc_tau_polytomous` and `calc_info_tau_polytomous`, extend the existing dichotomous IRT functions to handle polytomous models. The key changes involve handling the additional categories for each item by summing the probabilities or information across all categories before raising to powers or summing across items. These functions are flexible enough to work with polytomous IRT models like GRM, PCM, and GPCM, making them suitable for a variety of testing scenarios.

To extend the existing dichotomous IRT models to polytomous models, we will focus on three widely used polytomous models in IRT:

 1. **Graded Response Model (GRM)**: Typically used for ordinal items, this model estimates the probability of responding at or above a certain category.
 2. **Partial Credit Model (PCM)**: This is a generalization of the Rasch model for polytomous items, where the probability of a response in each category depends on the difference between a person’s ability and the item thresholds.
 3. **Generalized Partial Credit Model (GPCM)**: A further generalization of PCM that includes a discrimination parameter.

Let's create functions that compute the **probability of correct response** and the **item information** for each of these models.

### 1. **Graded Response Model (GRM)**

#### Probability of Response for GRM:

The GRM calculates the probability of a response at or above a given category \( k \) for an item with difficulty thresholds \( b_k \) and discrimination parameter \( a \). The probability is computed as follows:

\[
P(Y \geq k | \theta) = \frac{1}{1 + \exp(-a(\theta - b_k))}
\]

#### Item Information for GRM:

The item information for the GRM can be computed by summing the category information for each threshold:

\[
I(\theta) = \sum_{k=1}^{K-1} \left[ P(Y \geq k | \theta) \cdot (1 - P(Y \geq k | \theta)) \cdot a^2 \right]
\]

### GRM Functions:

```julia
function prob_grm(a::Float64, b::Vector{Float64}, θ::Float64)
    K = length(b) + 1  # Number of categories
    prob = zeros(Float64, K)

    # Compute probabilities for response categories
    for k in 1:(K - 1)
        prob[k] = 1.0 / (1.0 + exp(-a * (θ - b[k])))
    end

    # For the last category, probability is 1
    prob[K] = 1.0

    # Convert to probability of response in category
    prob_category = zeros(Float64, K)
    prob_category[1] = 1 - prob[1]
    for k in 2:(K - 1)
        prob_category[k] = prob[k - 1] - prob[k]
    end
    prob_category[K] = prob[K - 1]

    return prob_category
end

function info_grm(a::Float64, b::Vector{Float64}, θ::Float64)
    K = length(b) + 1  # Number of categories
    prob = prob_grm(a, b, θ)
    info = 0.0

    # Calculate item information
    for k in 1:(K - 1)
        p = prob[k]
        info += a^2 * p * (1 - p)
    end

    return info
end
```

### 2. **Partial Credit Model (PCM)**

#### Probability of Response for PCM:

The PCM calculates the probability of a response in category \( k \) using the following formula:

\[
P(Y = k | \theta) = \frac{\exp(\sum_{j=0}^{k} a(\theta - b_j))}{\sum_{k'=0}^{K} \exp(\sum_{j=0}^{k'} a(\theta - b_j))}
\]

#### Item Information for PCM:

Item information for the PCM is calculated by summing the information over all categories, based on the response probabilities:

\[
I(\theta) = \sum_{k=0}^{K} P(Y = k | \theta) \cdot \left( \frac{\partial \log P(Y = k | \theta)}{\partial \theta} \right)^2
\]

### PCM Functions:

```julia
function prob_pcm(a::Float64, b::Vector{Float64}, θ::Float64)
    K = length(b)  # Number of categories
    numerators = zeros(Float64, K + 1)

    # Compute numerator for each category
    for k in 0:K
        sum_term = sum(a * (θ - b[j]) for j in 1:k)
        numerators[k + 1] = exp(sum_term)
    end

    # Compute denominator (sum of numerators)
    denominator = sum(numerators)

    # Compute probabilities for each category
    prob_category = numerators / denominator
    return prob_category
end

function info_pcm(a::Float64, b::Vector{Float64}, θ::Float64)
    K = length(b)  # Number of categories
    prob = prob_pcm(a, b, θ)
    info = 0.0

    # Calculate item information
    for k in 1:(K + 1)
        p = prob[k]
        log_derivative = a * (k - sum(prob .* (0:K)))  # Gradient of log-probability
        info += p * log_derivative^2
    end

    return info
end
```

### 3. **Generalized Partial Credit Model (GPCM)**

#### Probability of Response for GPCM:

The GPCM extends the PCM by adding a discrimination parameter \( a \) that varies across items:

\[
P(Y = k | \theta) = \frac{\exp(a_k \sum_{j=0}^{k} (\theta - b_j))}{\sum_{k'=0}^{K} \exp(a_{k'} \sum_{j=0}^{k'} (\theta - b_j))}
\]

#### Item Information for GPCM:

The information for GPCM is computed similarly to PCM, but each category \( k \) has its own discrimination parameter \( a_k \), so the information calculation takes this into account:

\[
I(\theta) = \sum_{k=0}^{K} P(Y = k | \theta) \cdot \left( \frac{\partial \log P(Y = k | \theta)}{\partial \theta} \right)^2
\]

### GPCM Functions:

```julia
function prob_gpcm(a::Vector{Float64}, b::Vector{Float64}, θ::Float64)
    K = length(b)  # Number of categories
    numerators = zeros(Float64, K + 1)

    # Compute numerator for each category
    for k in 0:K
        sum_term = sum(a[j] * (θ - b[j]) for j in 1:k)
        numerators[k + 1] = exp(sum_term)
    end

    # Compute denominator (sum of numerators)
    denominator = sum(numerators)

    # Compute probabilities for each category
    prob_category = numerators / denominator
    return prob_category
end

function info_gpcm(a::Vector{Float64}, b::Vector{Float64}, θ::Float64)
    K = length(b)  # Number of categories
    prob = prob_gpcm(a, b, θ)
    info = 0.0

    # Calculate item information
    for k in 1:(K + 1)
        p = prob[k]
        log_derivative = a[k] * (k - sum(prob .* (0:K)))  # Gradient of log-probability
        info += p * log_derivative^2
    end

    return info
end
```

### Conclusion:

Each of the models above—**GRM**, **PCM**, and **GPCM**—can now handle polytomous items, allowing you to calculate the probability of a response in each category and the item information at various ability levels (θ). These functions will work similarly to the dichotomous functions you've been using, but they are tailored for ordinal and polytomous data typically seen in educational and psychological assessments with more than two response categories.

The current objective functions for **Test Assembly Optimization**—such as `objective_match_characteristic_curve!`, `objective_match_information_curve!`, and `objective_max_info`—are based on **dichotomous** IRT models. They use the probability of correct response (for the characteristic curve) and item information (for the information curve) based on dichotomous items.

To assess whether these functions can be applied to **polytomous** IRT models, we need to consider the following:

### Differences Between Dichotomous and Polytomous Models:

 1. **Dichotomous vs. Polytomous Responses**:
    
      + In dichotomous models, items have two possible outcomes (correct/incorrect), and the functions are written to sum over these binary outcomes.
      + In polytomous models, items have multiple possible outcomes (multiple categories). Each category will have its own probability, and summing over categories is more complex.

 2. **Probability Calculations**:
    
      + The functions like `objective_match_characteristic_curve!` sum the probability of a correct response raised to a power. In polytomous models, there are multiple probabilities (for each category) instead of just one, so the structure of the summation needs to change.
 3. **Item Information**:
    
      + Similarly, item information in dichotomous models is calculated based on a single information function per item. For polytomous items, the information is calculated for each category, and then combined across categories.

### Analysis of the Current Functions:

 1. **`objective_match_characteristic_curve!`**:
    
      + The current function sums the probability of a correct response (`P[i, k]`) raised to a power `r`. In polytomous models, each item will have multiple probabilities (for each category), so we would need to modify the summation to handle these multiple probabilities.
      + The current constraint formulation works for binary outcomes but will need to be extended to sum over all categories in the polytomous model.

 2. **`objective_match_information_curve!`**:
    
      + Similar to the characteristic curve function, this function sums the item information (`info[i, k]`). In polytomous models, the information is not a single value but depends on the probabilities of all categories. We will need to modify this function to sum the information contributions from all response categories.
 3. **`objective_max_info`**:
    
      + This function maximizes the total information by ensuring the sum of item information meets or exceeds a target. For polytomous models, the information per item will also need to consider all categories, not just a single dichotomous outcome.

### Changes Required for Polytomous Models:

 1. **Summing Over Categories**:
    
      + For both the characteristic curve and information curve, we need to modify the summation to handle the multiple categories in polytomous models. For each item, we will sum the contributions from all response categories, rather than just summing over a single correct/incorrect outcome.

 2. **New Probability and Information Calculation**:
    
      + We will need to use the **polytomous probability functions** (e.g., `prob_grm`, `prob_pcm`, `prob_gpcm` for GRM, PCM, and GPCM, respectively) to compute the probabilities of responses in each category.
      + Similarly, we will need to adjust the information calculations to account for the information from all categories.

### Example Modifications for `objective_match_characteristic_curve!`:

Here’s how we might modify the `objective_match_characteristic_curve!` function to handle **polytomous** models:

```julia
function objective_match_characteristic_curve_polytomous!(model::Model, parms::Parameters)
    R, K = 1:(parms.r), 1:(parms.k)
    P = parms.p  # Polytomous probabilities (3D matrix: items x theta_points x categories)
    tau = parms.tau
    x, y = model[:x], model[:y]
    items, forms = size(x)
    zcol = forms
    forms -= parms.shadow_test_size > 0 ? 1 : 0

    # Weights for characteristic curve constraint
    w = [1.0 for _ in R]

    # Identify anchor and non-anchor items
    anchor_items = findall(parms.bank.ANCHOR .!== missing)
    non_anchor_items = filter(i -> ismissing(parms.bank.ANCHOR[i]), 1:items)

    # Contribution of anchor items to characteristic curve (sum over all categories)
    anchor_contribution = Dict()
    for k in K, r in R
        anchor_contribution[k, r] = sum(sum(P[i, k, :] .^ r) for i in anchor_items)
    end

    # Constraints for operational forms (include both anchor and non-anchor items, summing over categories)
    @constraint(model,
        [f = 1:forms, k = K, r = R],
        sum(sum(P[i, k, :] .^ r) * x[i, f] for i in 1:items)<=tau[r, k] + (w[r] * y))
    @constraint(model,
        [f = 1:forms, k = K, r = R],
        sum(sum(P[i, k, :] .^ r) * x[i, f] for i in 1:items)>=tau[r, k] - (w[r] * y))

    # Constraints for shadow test (only non-anchor items, summing over categories)
    if parms.shadow_test_size > 0
        shadow_test_size = parms.shadow_test_size
        w_shadow = [1.0, 0.8, 0.7, 0.75]

        # Adjust constraints for the shadow test, subtracting anchor contribution
        @constraint(model,
            [k = K, r = R],
            sum(sum(P[i, k, :] .^ r) * x[i, zcol]
            for i in non_anchor_items)<=(
                (tau[r, k] - anchor_contribution[k, r] + (w_shadow[r] * y)) *
                shadow_test_size
            ))
        @constraint(model,
            [k = K, r = R],
            sum(sum(P[i, k, :] .^ r) * x[i, zcol]
            for i in non_anchor_items)>=(
                (tau[r, k] - anchor_contribution[k, r] - (w_shadow[r] * y)) *
                shadow_test_size
            ))
    end

    return model
end
```

### Key Changes:

 1. **Summing Over Categories**: We sum over all categories for each item using `sum(P[i, k, :] .^ r)` to handle the multiple probabilities in polytomous models.
 2. **Anchor Contribution**: Anchor items contribute to the characteristic curve through the sum of probabilities across all categories.
 3. **Constraints**: We adjust the constraints to sum the probabilities over all categories and apply them both to operational forms and shadow tests.

### Other Functions:

  - **`objective_match_information_curve!`** and **`objective_max_info`** would need similar modifications:
    
      + For `objective_match_information_curve!`, we would sum the information over all categories for each item.
      + For `objective_max_info`, we would maximize the information by ensuring the sum over all categories meets or exceeds the target.

### Conclusion:

The existing optimization functions for **Test Assembly** can be adapted for **polytomous models** by modifying the way probabilities and information are summed over categories. The general structure of the constraints remains valid, but we need to account for the multiple response categories in polytomous items by summing over these categories in both the characteristic curve and information calculations.

To adapt the `objective_match_characteristic_curve!` function for **polytomous** items, we need to account for the fact that each item can have multiple response categories. Instead of simply calculating the probability of a correct response, we need to calculate and sum over the probabilities for all response categories.

### Key Changes for Polytomous Items:

 1. **Probability Matrix**: In the polytomous case, the probability matrix `P` will have one dimension for items, one for theta points, and one for the response categories. We need to sum over the response categories for each item.

 2. **Anchor Contribution**: The contribution of anchor items to the characteristic curve should consider all response categories.
 3. **Summing Over Categories**: When setting constraints, we need to sum over the probabilities of all categories for each item.

### Modified Function for Polytomous Items:

```julia
function objective_match_characteristic_curve_polytomous!(model::Model, parms::Parameters)
    R, K = 1:(parms.r), 1:(parms.k)
    P = parms.p  # Polytomous probabilities (3D matrix: items x theta_points x categories)
    tau = parms.tau
    x, y = model[:x], model[:y]
    items, forms = size(x)
    zcol = forms
    forms -= parms.shadow_test_size > 0 ? 1 : 0

    # Weights for characteristic curve constraint
    w = [1.0 for _ in R]

    # Identify anchor and non-anchor items
    anchor_items = findall(parms.bank.ANCHOR .!== missing)
    non_anchor_items = filter(i -> ismissing(parms.bank.ANCHOR[i]), 1:items)

    # Contribution of anchor items to characteristic curve (sum over all categories)
    anchor_contribution = Dict()
    for k in K, r in R
        anchor_contribution[k, r] = sum(sum(P[i, k, :] .^ r) for i in anchor_items)
    end

    # Constraints for operational forms (include both anchor and non-anchor items, summing over categories)
    @constraint(model,
        [f = 1:forms, k = K, r = R],
        sum(sum(P[i, k, :] .^ r) * x[i, f] for i in 1:items)<=tau[r, k] + (w[r] * y))
    @constraint(model,
        [f = 1:forms, k = K, r = R],
        sum(sum(P[i, k, :] .^ r) * x[i, f] for i in 1:items)>=tau[r, k] - (w[r] * y))

    # Constraints for shadow test (only non-anchor items, summing over categories)
    if parms.shadow_test_size > 0
        shadow_test_size = parms.shadow_test_size
        w_shadow = [1.0, 0.8, 0.7, 0.75]

        # Adjust constraints for the shadow test, subtracting anchor contribution
        @constraint(model,
            [k = K, r = R],
            sum(sum(P[i, k, :] .^ r) * x[i, zcol]
            for i in non_anchor_items)<=(
                (tau[r, k] - anchor_contribution[k, r] + (w_shadow[r] * y)) *
                shadow_test_size
            ))
        @constraint(model,
            [k = K, r = R],
            sum(sum(P[i, k, :] .^ r) * x[i, zcol]
            for i in non_anchor_items)>=(
                (tau[r, k] - anchor_contribution[k, r] - (w_shadow[r] * y)) *
                shadow_test_size
            ))
    end

    return model
end
```

### Key Changes:

 1. **Probability Matrix**:
    
      + `P[i, k, :]`: This now represents the probability of response for item `i` at theta point `k` across all response categories. We sum these probabilities to get the total contribution of each item to the characteristic curve.

 2. **Anchor Contribution**:
    
      + For anchor items, we sum over all categories to compute their contribution to the characteristic curve for each combination of theta point `k` and power `r`.
 3. **Constraints for Operational Forms**:
    
      + For operational forms, we sum over both the items and the response categories, raising the probabilities to power `r` as required by the characteristic curve matching constraint.
 4. **Constraints for Shadow Test**:
    
      + For the shadow test, we apply similar constraints but only to non-anchor items, ensuring that the shadow test has enough flexibility while still adhering to the characteristic curve.

### Summary:

This modified function now handles **polytomous** items by considering multiple response categories for each item. It adjusts the constraints to sum over the response categories when matching the characteristic curve at different theta points. Anchor items are handled by summing over their contributions across all categories, and the shadow test is constrained accordingly.

To modify the `objective_match_information_curve!` function for **polytomous** items, we need to adapt it to handle the information provided by each category of the items, rather than just a single information value per item as in dichotomous models. In polytomous models, each item has multiple response categories, and the information at each category contributes to the overall information curve.

### Key Changes for Polytomous Models:

 1. **Information Matrix**: In polytomous models, the information matrix `info` will have a third dimension corresponding to the response categories. We need to sum over the categories for each item to compute the total information.

 2. **Anchor Contribution**: The contribution of anchor items to the information curve should sum over all response categories.
 3. **Summing Over Categories**: The constraints need to be updated to sum over the information for all categories for each item.

### Modified Function for Polytomous Items:

```julia
function objective_match_information_curve_polytomous!(model::Model, parms::Parameters)
    K, info, tau_info = parms.k, parms.info, parms.tau_info
    x, y = model[:x], model[:y]
    items, forms = size(x)
    zcol = forms
    forms -= parms.shadow_test_size > 0 ? 1 : 0

    # Identify anchor and non-anchor items
    anchor_items = findall(parms.bank.ANCHOR .!== missing)
    non_anchor_items = filter(i -> ismissing(parms.bank.ANCHOR[i]), 1:items)

    # Contribution of anchor items to the information curve (sum over categories)
    anchor_info_contribution = Dict()
    for k in 1:K
        anchor_info_contribution[k] = sum(sum(info[i, k, :]) for i in anchor_items)
    end

    # Constraints for operational forms (include both anchor and non-anchor items, summing over categories)
    @constraint(model,
        [f = 1:forms, k = 1:K],
        sum(sum(info[i, k, :]) * x[i, f] for i in 1:items)<=tau_info[k] + y)
    @constraint(model,
        [f = 1:forms, k = 1:K],
        sum(sum(info[i, k, :]) * x[i, f] for i in 1:items)>=tau_info[k] - y)

    # Constraints for shadow test (only non-anchor items, summing over categories)
    if parms.shadow_test_size > 0
        shadow_test_size = parms.shadow_test_size

        # Adjust constraints for the shadow test, subtracting anchor contribution
        @constraint(model,
            [k = 1:K],
            sum(sum(info[i, k, :]) * x[i, zcol]
            for i in non_anchor_items)<=
            (tau_info[k] + y - anchor_info_contribution[k]) * shadow_test_size)
        @constraint(model,
            [k = 1:K],
            sum(sum(info[i, k, :]) * x[i, zcol]
            for i in non_anchor_items)>=
            (tau_info[k] - y - anchor_info_contribution[k]) * shadow_test_size)
    end

    return model
end
```

### Key Changes:

 1. **Information Matrix**:
    
      + `info[i, k, :]`: This now represents the information for item `i` at theta point `k` across all response categories. We sum the information over all categories to compute the total contribution of each item.

 2. **Anchor Contribution**:
    
      + For anchor items, we sum the information across all categories to compute their contribution to the information curve at each theta point.
 3. **Constraints for Operational Forms**:
    
      + We sum over the items and response categories to compute the total information for the operational forms, ensuring the total information stays within the bounds set by `tau_info[k] ± y`.
 4. **Constraints for Shadow Test**:
    
      + For the shadow test, we sum the information over non-anchor items and categories, applying the same constraint logic but excluding anchor items to maintain flexibility.

### Summary:

This modified function now handles **polytomous** items by summing the information across all response categories for each item. The anchor items are handled by summing their contributions to the information curve, and the shadow test constraints are applied only to non-anchor items. This ensures that the total information curve is correctly matched for both operational forms and the shadow test while handling the complexity of polytomous items.

To modify the `objective_max_info` function for **polytomous** items, we need to account for the fact that the information for each item is spread across multiple response categories. The current version of the function calculates the total item information based on a single value per item, which works for dichotomous items, but for polytomous items, we must sum the information across all categories.

### Key Changes for Polytomous Models:

 1. **Information Matrix**: In polytomous models, the information matrix `info` will have a third dimension for the response categories. We need to sum the information across the categories to calculate the total item information.

 2. **Anchor Contribution**: The contribution of anchor items to the total information should consider all response categories.
 3. **Constraints**: The constraints need to sum the information over all categories for each item to ensure the total information meets or exceeds the weighted target at each point.

### Modified Function for Polytomous Items:

```julia
function objective_max_info_polytomous!(model::Model, parms::Parameters)
    R = parms.relative_target_weights
    K = parms.k
    info = parms.info  # Polytomous information matrix: items x theta_points x categories
    x, y = model[:x], model[:y]
    items, forms = size(x)

    shadow = parms.shadow_test_size
    forms -= shadow > 0 ? 1 : 0

    # Identify anchor and non-anchor items
    anchor_items = findall(parms.bank.ANCHOR .!== missing)
    non_anchor_items = filter(i -> ismissing(parms.bank.ANCHOR[i]), 1:items)

    # Calculate the contribution of anchor items for each k (sum over categories)
    anchor_info_contribution = Dict()
    for k in 1:K
        anchor_info_contribution[k] = sum(sum(info[i, k, :]) for i in anchor_items)
    end

    # Constraints for operational forms (include both anchor and non-anchor items, summing over categories)
    @constraint(model,
        [f = 1:forms, k = 1:K],
        sum(sum(info[i, k, :]) * x[i, f] for i in 1:items)>=R[k] * y)

    # Constraints for shadow test (exclude anchor items, summing over categories)
    if shadow > 0
        @constraint(model,
            [k = 1:K],
            sum(sum(info[i, k, :]) * x[i, forms + 1]
            for i in non_anchor_items)>=
            (R[k] * y * shadow - anchor_info_contribution[k]))
    end

    return model
end
```

### Key Changes:

 1. **Information Matrix**:
    
      + `info[i, k, :]`: This now represents the information for item `i` at theta point `k` across all response categories. We sum over the response categories to compute the total information contribution of each item.

 2. **Anchor Contribution**:
    
      + For anchor items, we sum the information over all categories to compute their contribution to the total information at each theta point. This ensures that the anchor items' information is appropriately accounted for.
 3. **Constraints for Operational Forms**:
    
      + We sum the information for both anchor and non-anchor items across categories, ensuring that the total information meets or exceeds the target (`R[k] * y`) at each theta point.
 4. **Constraints for Shadow Test**:
    
      + The shadow test constraints are similar but apply only to non-anchor items. We sum over categories to compute the total information for non-anchor items and subtract the anchor contribution.

### Summary:

This modified version of `objective_max_info` now handles **polytomous** items by summing the information across all response categories for each item. The function ensures that the total information for each theta point meets or exceeds the target, while handling both anchor and non-anchor items appropriately. The shadow test is constrained to non-anchor items, allowing for flexibility in test assembly.

To extend the current CSV file format to handle polytomous items' parameters, you'll need to include additional fields that define the parameters for each category of the polytomous items. Polytomous models such as the Graded Response Model (GRM), Partial Credit Model (PCM), or Generalized Partial Credit Model (GPCM) typically require:

  - **Thresholds** for each category (e.g., for GRM or PCM).
  - **Discrimination parameters** for each item (which may vary across categories in models like GPCM).

Here’s a suggested structure for how to include these parameters in the CSV file while preserving backward compatibility with dichotomous items:

### Updated CSV Structure for Polytomous Items:

| ID       | A       | B1       | B2   | B3   | C       | AREA | SUBAREA | FRIENDS | ENEMIES | WORDS | IMAGES | DIF | CORR | NUM_CATEGORIES | MODEL_TYPE |
|:-------- |:------- |:-------- |:---- |:---- |:------- |:---- |:------- |:------- |:------- |:----- |:------ |:--- |:---- |:-------------- |:---------- |
| ITEM0033 | 0.7591  | -0.39276 | -0.9 |      | 0.02882 | 2    | 0002-03 | 1       | 1       | 60    | 5      | 20  | 0.25 | 2              | GRM        |
| ITEM0014 | 0.87269 | -1.26518 | -0.5 | 0.25 | 0.06343 | 2    | 0002-02 | 1       |         | 20    | 3      | 50  | 0.38 | 3              | PCM        |

### Explanation:

 1. **`A`**: Discrimination parameter (may be constant or vary across categories, depending on the model).
 2. **`B1`, `B2`, `B3`, ...**: Threshold parameters for each category. For example, in the GRM, `B1` might represent the threshold for moving from category 1 to category 2, `B2` for category 2 to 3, etc. You can include as many `B` columns as necessary to represent the number of categories for each item.
 3. **`C`**: This could still be used for the guessing parameter in models that require it (e.g., for dichotomous items), but it may not be necessary for polytomous models like GRM or PCM.
 4. **`NUM_CATEGORIES`**: The number of response categories for this item.
 5. **`POLY_MODEL_TYPE`**: This column indicates the polytomous model used for the item (e.g., "GRM", "PCM", or "GPCM"). This allows the program to interpret the parameters correctly.

### Additional Considerations:

  - For dichotomous items, the existing fields (`A`, `B`, `C`) can remain as is. For polytomous items, you add extra threshold parameters (`B2`, `B3`, etc.) and specify the number of categories and model type.
  - The new `POLY_MODEL_TYPE` field would tell the system whether the item is dichotomous or polytomous and which model to use for interpreting the parameters.

### Example Rows:

 1. **Dichotomous Item (Unchanged)**:
    
    ```
    ITEM0033,0.7591,-0.39276,,0.02882,2,0002-03,1,1,60,5,20,0.25,1,Dichotomous
    ```

 2. **Polytomous Item (GRM)**:
    
    ```
    ITEM0045,1.230,-1.50,-0.75,0.5,,3,0003-02,2,,30,2,10,0.45,4,GRM
    ```

This approach should allow your current file format to support both dichotomous and polytomous items, providing flexibility for handling different IRT models while maintaining backward compatibility. Does this structure align with your needs?
