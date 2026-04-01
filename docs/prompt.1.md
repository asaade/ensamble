I need help reviewing and potentially rewriting a Julia function named `lw_dist`. This function uses the Lord-Wingersky recursion method to compute the distribution of possible test scores for a specified ability level `θ` in Item Response Theory (IRT). The function supports both dichotomous items (binary outcomes, such as correct/incorrect) and polytomous items (multiple ordered response categories). Below is the context and an implementation to serve as a basis for review and improvement.

### Purpose
The `lw_dist` function calculates the probability distribution of possible scores on a test given an ability level `θ`. It does so by applying the Lord-Wingersky recursion, which updates the probability of obtaining different scores as each test item is processed.

### Input Parameters
- **`item_params`**: A vector of tuples where each tuple contains parameters for a single item:
  - `a` (discrimination parameter): Measures how well the item differentiates between individuals of different ability levels.
  - `bs` (difficulty parameters): Represents the difficulty levels. For polytomous items, `bs` is a vector; for dichotomous items, it is a single value.
  - `c` (guessing parameter): Used in certain models like 3PL; set to `0` for other models where guessing is not applicable.
  - `model` (IRT model type): Specifies the item model type (e.g., "2PL", "3PL", "PCM", "GPCM").
- **`θ` (theta)**: The ability level of the examinee for which the score distribution is being computed.
- Optional parameter:
  - **`D`**: A scaling constant used in IRT models (typically set to 1 or 1.7).

### Core Function Logic
1. **Initialization**:
   - The function initializes a result vector `res` with all probability mass at score 0, representing the starting state.
2. **Iterative Score Update**:
   - For each item, it computes response probabilities using a helper function `prob_item`.
   - The function then updates the score distribution (`res`) based on the probabilities of achieving each possible score:
     - **Dichotomous Items**: Updates probabilities based on correct/incorrect responses.
     - **Polytomous Items**: Uses the extended recursion method to handle multiple response categories.
3. **Probability Accumulation**:
   - A temporary vector `prov` accumulates probabilities for each possible score during each iteration.

### Sample Implementation to Serve as Reference
The following implementation of `lw_dist` aims to provide a clear and comprehensible example for reviewing or rewriting:

---

### Sample Implementation

```julia
"""
    lw_dist(item_params::Vector{Tuple{Float64, Vector{Float64}, Float64, String}}, θ; D = 1.0)

Computes the distribution of observed scores for a given ability level `θ` using
the Lord-Wingersky recursion method.

# Arguments
- `item_params::Vector{Tuple{Float64, Vector{Float64}, Float64, String}}`:
   A vector of tuples where each tuple contains the parameters for one item:
   discrimination (`a`), difficulty (`bs`), guessing (`c`), and model type (`model`).
- `θ`: Ability level for which to compute the score distribution.
- `D::Float64=1.0`: Scaling constant for IRT models.

# Returns
- `Vector{Float64}`: A vector representing the probability distribution of possible test scores for ability `θ`.
"""
function lw_dist(item_params::Vector{Tuple{Float64, Vector{Float64}, Float64, String}}, θ; D = 1.0)
    num_items = length(item_params)

    # Handle empty input case
    if num_items == 0
        return [1.0]  # Return trivial distribution if no items
    end

    # Calculate the maximum possible score
    max_score = sum(
        if model == "3PL" || model == "2PL"
            1  # Dichotomous items contribute 1 point
        else
            max(0, length(bs) - 1)  # Polytomous items contribute (num categories - 1) points
        end
        for (a, bs, c, model) in item_params
    )

    # Initialize result vector with all probability at score 0
    res = zeros(max_score + 1)
    res[1] = 1.0

    # Iterate over each item
    for i in 1:num_items
        a, bs, c, model = item_params[i]
        response_probs = prob_item(model, a, bs, c, θ; D)  # Compute response probabilities
        prov = zeros(length(res))

        # Update score probabilities
        for current_score in 0:max_score
            current_prob = res[current_score + 1]
            if current_prob > 1e-10  # Only proceed if there is a significant probability mass
                for (cat_idx, cat_prob) in enumerate(response_probs)
                    new_score = current_score + (cat_idx - 1)  # Adjust for category score increment
                    if 0 <= new_score < length(prov)
                        prov[new_score + 1] += cat_prob * current_prob
                    end
                end
            end
        end

        # Update result vector
        res .= prov
    end

    return res
end
```

### Areas for Improvement and Considerations
1. **Correct Probability Accumulation**:
   - Ensure accurate propagation and accumulation of probabilities for both dichotomous and polytomous items.
2. **Efficiency and Numerical Stability**:
   - Optimize handling of small probabilities and computational efficiency, especially for large item pools or many categories.
3. **Differentiating Logic for Dichotomous vs. Polytomous Items**:
   - Clear handling and separation of logic for different item types, while avoiding redundancy.
4. **Edge Cases and Validation**:
   - Handle edge cases (e.g., empty `bs` vectors) and validate input parameters to ensure they conform to expected values.

### Request
Could you help review and improve this function, focusing on ensuring correct probability propagation, adherence to theoretical principles of the Lord-Wingersky recursion, and efficient handling of mixed-format items (both dichotomous and polytomous)? Any suggestions for performance optimization and improved numerical stability would also be appreciated.
