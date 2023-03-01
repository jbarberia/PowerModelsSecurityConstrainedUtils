# PowerModelsSecurityConstrainedUtils
Is a package extension of the `PowerModelsSecurityConstrained` module.
Its objective is to provide the following functionalities:

- An abstraction to easy parse/write solution files and input data files.
- A function to evaluate the solution files using `PyCall` and the official evaluation script.
- Functionalities to export or evaluate a single contingency given the entire `case.con` file.

## Usage

### Parse a directory
Its also builds the data structure. In the directory specified the `case.con`, `case.inl`, `case.raw`, `case.rop` files exists.


```julia
data = parse_directory("scenario_1")
```

### Evaluate a solution
```julia
# Create only base case report in "scenario_1/details.csv"
evaluate_solution("solution1.txt"; scenario="scenario_1")

# Returns only base case and contingencies inside solution2.txt
evaluate_solution(
	"solution1.txt",
	"solution2.txt";
	scenario="scenario_1"
	) 

# Also parses data as a DataFrame
df = evaluate_solution(
	"solution1.txt",
	"solution2.txt";
	scenario="scenario_1",
	return_df=true)

```


