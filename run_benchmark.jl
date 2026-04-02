using Pkg
Pkg.activate(".")
Pkg.instantiate()

using CSV, DataFrames, Distributions
using Ensamble

# We will need to include charts.jl functions or use them directly.
# Let's see if we can use simulate_scores from Ensamble.DisplayResults.Charts
using Ensamble.DisplayResults.Charts
using BenchmarkTools

# Create a mock bank and results dataframe
bank = DataFrame(
    ID = ["Item$i" for i in 1:1000],
    MODEL = ["3PL" for i in 1:1000],
    A = rand(1000),
    B = rand(1000),
    C = rand(1000) .* 0.2
)

results_matrix = Matrix{Union{Missing, String}}(undef, 100, 50)
for i in 1:50
    # select 100 random items for each form
    selected_indices = rand(1:1000, 100)
    results_matrix[:, i] = bank.ID[selected_indices]
end
results = DataFrame(results_matrix, :auto)

dist = Normal(0, 1)

# Compile it once
res = simulate_scores(bank, results, dist)

println("Benchmarking simulate_scores...")
b = @benchmark simulate_scores($bank, $results, $dist)
display(b)
println()

