"""
    evaluate_solution(solution_file_1; output_file="details.csv", scenario="", return_df=false)

Read a `solution_1` file and returns it evaluation in `output_file`.
If `return_df=true` parses the `output_file` to a `DataFrame`.
"""
function evaluate_solution(solution_file_1; output_file="details.csv", scenario="", return_df=false)
    input_files = get_input_files(scenario)
    solution_file_2 = "none"
    run(`python $(MODULE_DIR)/Evaluation/test_solution_1.py $(input_files.raw) $(input_files.rop) $(input_files.con) $(input_files.inl) $(solution_file_1) $(solution_file_2) summary $(output_file)`)
    if return_df
        return DataFrame(CSV.File(output_file))        
    end
end

"""
    evaluate_solution(solution_file_1, solution_file_2; output_file="details.csv", scenario="", return_df=false)

Read a `solution_1` and a `solution_2` file and returns it evaluation in `output_file`.
If `return_df=true` parses the `output_file` to a `DataFrame`.

The `solution_file_2` could be a single contingency solution file or a merge of differents contingencies.

This function make a tempfile of the `case.con` file in order to match the requirements of the ARPA official evaluation script.
"""
function evaluate_solution(solution_file_1, solution_file_2; output_file="details.csv", scenario="", return_df=false)
    input_files = get_input_files(scenario)
    
    if is_partial_solution_2(solution_file_2, scenario)
        contingency_file = read("$scenario/case.con", String)
        solution_2_string = read(solution_file_2, String)
        tmp = tempname()
        open(tmp, "w") do io
            labels = match(r"label.*$[\r\n](.*)"m, solution_2_string)
            for label in labels.captures
                pattern = Regex("^.*$label.*\$[\r\n](.*)", "m")
                contingency_info = match(pattern, contingency_file).captures[1]
                contingency_string = "CONTINGENCY $label\n$contingency_info\nEND\n"
                write(io, contingency_string)
            end
            write(io, "END\n")
        end
        run(`python $(MODULE_DIR)/Evaluation/test_both_solutions.py $(input_files.raw) $(input_files.rop) $(tmp) $(input_files.inl) $(solution_file_1) $(solution_file_2) summary $(output_file)`)
        rm(tmp)
    else
        run(`python $(MODULE_DIR)/Evaluation/test_both_solutions.py $(input_files.raw) $(input_files.rop) $(input_files.con) $(input_files.inl) $(solution_file_1) $(solution_file_2) summary $(output_file)`)
    end
    
    if return_df
        return DataFrame(CSV.File(output_file))        
    end
end

function is_partial_solution_2(solution_file, scenario)
    lines = length(readlines("$scenario/case.con"))
    contingencies_in_case = (lines - 1) ÷ 3
    contingencies_in_solution = length(collect(eachmatch(r"-- contingency", read(solution_file, String))))
    return contingencies_in_case != contingencies_in_solution
end

"""
    compute_bounds_violations(data::Dict{String, Any})::Dict{String, Any}

Compute the bounds of `vm`, `pg`, `qg` and `bs`. The output dict has the followings keys `vm_vio`, `pg_vio`, `qg_vio`, `bs_vio`
"""
function compute_bounds_violations(data::Dict{String, Any})::Dict{String, Any}
    violations = Dict()
    violations["bus"] = Dict()
    violations["gen"] = Dict()
    violations["shunt"] = Dict()

    for (i, bus) in data["bus"]
        bus["bus_type"] == 4 && continue
        upper_violation = max(0, bus["vm"] - bus["vmax"])
        lower_violation = max(0, bus["vmin"] - bus["vm"])
        violations["bus"][i] = Dict("vm_vio" => max(upper_violation, lower_violation))
    end

    for (i, gen) in data["gen"]
        gen["gen_status"] == 0 && continue
        violations["gen"][i] = Dict()
        # active power
        upper_violation = max(0, gen["pg"] - gen["pmax"])
        lower_violation = max(0, gen["pmin"] - gen["pg"])
        violations["gen"][i]["pg_vio"] = max(upper_violation, lower_violation)
        # reactive power
        upper_violation = max(0, gen["qg"] - gen["qmax"])
        lower_violation = max(0, gen["qmin"] - gen["qg"])
        violations["gen"][i]["qg_vio"] = max(upper_violation, lower_violation)
    end

    for (i, shunt) in data["shunt"]
        !haskey(shunt, "bmax") && continue
        !haskey(shunt, "bmin") && continue
        upper_violation = max(0, shunt["bs"] - shunt["bmax"])
        lower_violation = max(0, shunt["bmin"] - shunt["bs"])
        violations["shunt"][i] = Dict("b_vio" => max(upper_violation, lower_violation))
    end

    violations["baseMVA"] = data["baseMVA"]
    violations["per_unit"] = true
    return violations
end

"""
    compute_flow_violations(data, rate="rate_a")::Dict{String, Any}

Compute the associate slack value of the branch flow violations.
"""
function compute_flow_violations(data, rate="rate_a")::Dict{String, Any}
    flows = calc_c1_branch_flow_ac(data)["branch"]
    violations = Dict()
    for (i, branch) in data["branch"]
        branch["br_status"] == 0 && continue
        ! haskey(branch, rate) && continue
        rating = branch[rate]
        sf = sqrt(flows[i]["pf"]^2 + flows[i]["qf"]^2)
        st = sqrt(flows[i]["pt"]^2 + flows[i]["qt"]^2)

        if branch["transformer"]
            violations[i] = max(sf, st) - rating
            violations[i] = max(0, violations[i])
        else
            vm_f = data["bus"]["$(branch[string(:f_bus)])"]["vm"]
            vm_t = data["bus"]["$(branch[string(:t_bus)])"]["vm"]
            violations[i] = max(sf/vm_f, st/vm_t) - rating
            violations[i] = max(0, violations[i])
        end
    end

    return Dict(
        "baseMVA" => data["baseMVA"],
        "per_unit" => true,
        "branch" => violations
        )
end

"""
    compute_power_balance_violations(data::Dict{String, Any})::Dict{String, Any}

Compute mismatch of P and Q on every bus. 
The keys are `p_deltas` and `q_deltas`.
"""
function compute_power_balance_violations(data::Dict{String, Any})::Dict{String, Any}
    data = copy(data)
    flows = calc_c1_branch_flow_ac(data)
    update_data!(data, flows)
    balance_violations = calc_power_balance(data)

    return balance_violations
end
