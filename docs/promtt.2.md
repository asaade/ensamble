I need help reviewing and potentially rewriting a Julia function named observed_score_continuous. This function computes the expected distribution of observed scores on a test using the Lord-Wingersky recursion, integrated over a continuous distribution of examinee abilities using numerical integration (quadgk). Below is an overview of the function's purpose, context, and logic, along with a sample implementation to serve as a base for improvements.

Purpose
The observed_score_continuous function estimates the observed score distribution of a test given a specified ability distribution among examinees. This is useful for modeling the distribution of scores that a population of test-takers is expected to achieve, based on their ability levels.

Integration with Other Functions
The function relies on a separate function called lw_dist to compute the score distribution for a single ability level (θ) using the Lord-Wingersky recursion. This recursion handles both dichotomous items (binary outcomes) and polytomous items (multiple ordered categories).

Input Parameters
item_params: A vector of tuples representing parameters for each test item. Each tuple includes:
a (discrimination parameter)
bs (difficulty parameters; vector for polytomous items, single value for dichotomous items)
c (guessing parameter, relevant for models like the 3PL)
model (the IRT model type, e.g., "3PL", "PCM")

ability_dist: A continuous univariate distribution (e.g., Normal(0, 1)) representing the distribution of examinee abilities.
Optional parameters:
D: A scaling constant used in IRT models (typically 1 or 1.7).
num_points: Number of points used for integration over the ability distribution.

Core Function Logic
Maximum Possible Score Calculation:
The function determines the maximum possible score by summing the maximum contributions of each item based on the item model and number of categories.

Integration with Numerical Integration (quadgk):
The function performs numerical integration over the ability distribution to compute the expected probability of achieving each possible test score.

Result Aggregation:
The result is a vector representing the probabilities of obtaining each possible test score, given the specified ability distribution.

Function to Review and Improve
Below is a sample implementation of observed_score_continuous to serve as a basis for review and potential improvement:

Sample Implementation
"""
observed_score_continuous(item_params, ability_dist; D = 1.0, num_points = 120)

Computes the observed score distribution for a test given a set of item parameters
and an ability distribution, using the Lord-Wingersky recursion and numerical integration.

# Arguments

  - `item_params::Vector{Tuple{Float64, Vector{Float64}, Float64, String}}`:
    A vector of tuples representing parameters for each item, including discrimination (`a`),
    difficulty parameters (`bs`), guessing parameter (`c`), and model type (`model`).
  - `ability_dist::ContinuousUnivariateDistribution`:
    The distribution of abilities (e.g., `Normal(0, 1)`).
  - `D::Float64=1.0`:
    Scaling constant for IRT models (typically set to 1 or 1.7).
  - `num_points::Int=120`:
    Number of points used for integration over the ability distribution.

# Returns

  - `Vector{Float64}`: The observed score distribution as a vector.
    """
    function observed_score_continuous(item_params::Vector{Tuple{Float64, Vector{Float64}, Float64, String}}, ability_dist::ContinuousUnivariateDistribution; D = 1.0, num_points = 120)
    
    # Calculate the maximum possible score
    
    max_score = sum(length(prob_item(item_params[i][4], item_params[i][1], item_params[i][2], item_params[i][3], 0.0; D)) - 1 for i in 1:length(item_params))
    observed_dist = zeros(max_score + 1)  # Initialize result vector for score probabilities
    
    # Define an inner function to compute the integrand for numerical integration
    
    function integrand(θ, x)
    score_dist = lw_dist(item_params, θ; D)  # Compute the score distribution using Lord-Wingersky recursion
    if x + 1 > length(score_dist)  # Check for bounds to avoid indexing errors
    return 0.0
    end
    return score_dist[x + 1] * pdf(ability_dist, θ)  # Weight by the probability density of the ability distribution
    end
    
    # Compute the observed distribution for each possible score by integrating over the ability distribution
    
    for x in 0:max_score
    observed_dist[x + 1] = quadgk(θ -> integrand(θ, x), -Inf, Inf; order = num_points)[1]
    end
    return observed_dist
    end

  - Areas for Improvement and Considerations

Integration Performance:
Numerical integration can be computationally expensive for large numbers of items or complex distributions. Consider optimizations to improve performance.

Correct Probability Accumulation:
Ensure that the probabilities are correctly accumulated for all possible scores, particularly for mixed-format tests with dichotomous and polytomous items.

Validation:
Add input validation to ensure item_params and ability_dist are correctly formatted.

Edge Cases:
Consider handling edge cases, such as when the score distribution has very small probability values that may lead to numerical instability.

Request
Could you review and help improve this function, ensuring accurate probability accumulation across scores and better adherence to the theoretical principles of the Lord-Wingersky recursion? Optimizations for performance and numerical stability would also be highly beneficial.
