module PowerModelsSecurityConstrainedUtils
using PowerModels, PowerModelsSecurityConstrained
using PyCall
using CSV
using DataFrames

const MODULE_DIR = @__DIR__()

function __init__()
    pushfirst!(PyVector(pyimport("sys")."path"), "Evaluation/")
end


include("io.jl")
include("evaluation.jl")
include("data_structures.jl")
export parse_directory, write_solution_1, write_solution_2, read_solution_1, read_solution_2, merge_solutions_2, evaluate_solution, to_dataframe


end