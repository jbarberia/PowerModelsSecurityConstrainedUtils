"""
    parse_directory(directory::String)

Parses a directory with the `case.con`, `case.inl`, `case.raw`, `case.rop`, files
"""
function parse_directory(directory::String)
    parsed_data = PowerModelsSecurityConstrained.parse_c1_files(
        "$directory/case.con",
        "$directory/case.inl",
        "$directory/case.raw",
        "$directory/case.rop",
    )
    data = PowerModelsSecurityConstrained.build_c1_pm_model(parsed_data)
    return data
end

"""
    write_solution_1(data::Dict{String, Any}, filename::String)

Writes a solution 1 file according to ARPA-E requirements
"""
function write_solution_1(data::Dict{String, Any}, filename::String)
    PowerModelsSecurityConstrained.write_c1_solution1(data; solution_file=filename)
end

"""
    write_solution_2(data::Dict{String, Any}, filename::String)

Writes a single solution 2 file according to ARPA-E requirements.

*Notes*:
- The data dictionary must have a field `delta` on its root, else is gonna be zero.
- The data dictionary must have a field `label` wit the contingency label.
"""
function write_solution_2(data::Dict{String, Any}, filename::String)
    if !haskey(data, "delta")
        @warn("Delta value not found, Set it to default value of 0.0")
        data["delta"] = 0
    end

    if !haskey(data, "label")
        error("The data dict do not have a `label` field. Unable to write the file")
    end

    open(filename, "w") do io
        PowerModelsSecurityConstrained.write_c1_solution2_contingency(io, data, data)
    end
end

"""
    merge_solutions_2(filenames::Vector{String}, filename::String="solution_2.txt")

Given a list of contingencies filenames, reads it and merge into `filename` 

"""
function merge_solutions_2(filenames::Vector{String}, filename::String="solution_2.txt")
    open(filename, "w") do io
        for file in filenames
            write(io, open(file))
        end
    end
end

"""
    read_solution_1(data::Dict{String, Any}, filename::String)

Reads a solution 1 file and returns a `Dict`.

Usage:
```julia
    data = parse_directory("scenario")
    solution_1 = read_solution_1(data, "solution_1.txt")
    update_data!(data, solution_1)
```
"""
function read_solution_1(data::Dict{String, Any}, filename::String)
    return PowerModelsSecurityConstrained.read_c1_solution1(data; state_file=filename)
end

"""
    read_solution_2(data::Dict{String, Any}, filename::String)

Reads a solution 2 file and returns a `Dict`.
Do not turn out of service any component.

The idea of this function is to have a quickly workaround to check solution parameters.

Usage:
```julia
    data = parse_directory("scenario")
    solution_2 = read_solution_2(data, "solution_2.txt")
    update_data!(data, solution_2)
```
"""
function read_solution_2(data::Dict{String, Any}, filename::String)
    local contingency_label
    local delta
    local tempfile
    
    open(filename, "r") do io
        solution = read(io, String)
        contingency_label = match(
            r"-- contingency\nlabel[\r\n]+([^\r\n]+)"m,
            solution,
        ).captures[1]
        delta = match(
            r"-- delta section\ndelta\(MW\)[\r\n]+([^\r\n]+)"m,
            solution
        ).captures[1]
        solution_state = 4
        tempfile = tempname()
        open(tempfile, "w") do io
            write(io, solution_state)
        end
    end
    
    data_solution = read_solution_1(data, tempfile)
    data_solution["label"] = contingency_label
    data_solution["delta"] = parse(Float64, delta)
    rm(tempfile)
    return data_solution
end

"Return a tuple with the files"
function get_input_files(directory)
    !isfile("$directory/case.con") && error("case.con does not exist in $directory")
    !isfile("$directory/case.inl") && error("case.inl does not exist in $directory")
    !isfile("$directory/case.raw") && error("case.raw does not exist in $directory")
    !isfile("$directory/case.rop") && error("case.rop does not exist in $directory")

    return (;
        con = "$directory/case.con",
        inl = "$directory/case.inl",
        raw = "$directory/case.raw",
        rop = "$directory/case.rop",
    )
end