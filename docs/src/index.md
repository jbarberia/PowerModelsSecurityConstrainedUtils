# PowerModelsSecurityConstrainedUtils

It is a set of functionalities for the evaluation and processing of the results of the competition [ARPA-GOC-1](https://gocompetition.energy.gov/challenges/challenge-1).


# IO
This set of functions performs the read and write transformation easily.

```@docs
parse_directory(directory::String)
```

```@docs
write_solution_1(data::Dict{String, Any}, filename::String)
```

```@docs
write_solution_2(data::Dict{String, Any}, filename::String)
```

```@docs
merge_solutions_2(filenames::Vector{String}, filename::String="solution_2.txt")
```

```@docs
read_solution_1(data::Dict{String, Any}, filename::String)
```

```@docs
read_solution_2(data::Dict{String, Any}, filename::String)
```

# Evaluation
It is done trough the official ARPA evaluation script [(repo-here)](https://github.com/GOCompetition/Evaluation).

```@docs
evaluate_solution(solution_file_1; output_file="details.csv", scenario="", return_df=false)
```

```@docs
evaluate_solution(solution_file_1, solution_file_2; output_file="details.csv", scenario="", return_df=false)
```

## Computation of violations
There are the following functions to compute externally the values of the slacks variables.
All of this functions returns a dict that looks like:

```julia

result = Dict(
    "baseMVA" => 100,
    "per_unit" => true,
    "bus" => ...,
    "gen" => ...,
    "branch" => ...,
    ...
)
```

This allows to use the `update_data!` of the `PowerModels` package.

```@docs
compute_bounds_violations(data::Dict{String, Any})
```

```@docs
compute_flow_violations(data, rate="rate_a")
```

```@docs
compute_power_balance_violations(data::Dict{String, Any})
```
