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

"""
    compute_penalty(data::Dict{String, Any})

Return the penalty term according to ARPA-E without any weight factor.
"""
function compute_penalty(data::Dict{String, Any}, rating="rate_a")
    penalty_block_pow_real_max = [2.0, 50.0] # MW. when converted to p.u., this is overline_sigma_p in the formulation
    penalty_block_pow_real_coeff = [1000.0, 5000.0, 1000000.0] # USD/MW-h. when converted USD/p.u.-h this is lambda_p in the formulation
    penalty_block_pow_imag_max = [2.0, 50.0] # MVar. when converted to p.u., this is overline_sigma_q in the formulation
    penalty_block_pow_imag_coeff = [1000.0, 5000.0, 1000000.0] # USD/MVar-h. when converted USD/p.u.-h this is lambda_q in the formulation
    penalty_block_pow_abs_max = [2.0, 50.0] # MVA. when converted to p.u., this is overline_sigma_s in the formulation
    penalty_block_pow_abs_coeff = [1000.0, 5000.0, 1000000.0] # USD/MWA-h. when converted USD/p.u.-h this is lambda_s in the formulation

    power_balance_violations = compute_power_balance_violations(data)
    flow_violations = compute_flow_violations(data, rating)

    max_power_balance_real_violation = maximum(bus["p_delta"] |> abs for (i, bus) in power_balance_violations["bus"])
    max_power_balance_imag_violation = maximum(bus["q_delta"] |> abs for (i, bus) in power_balance_violations["bus"])
    power_balance_real_penalty = eval_piecewise_linear_penalty(max_power_balance_real_violation, penalty_block_pow_real_max, penalty_block_pow_real_coeff)
    power_balance_imag_penalty = eval_piecewise_linear_penalty(max_power_balance_imag_violation, penalty_block_pow_imag_max, penalty_block_pow_imag_coeff)
    
    max_flow_violation = maximum(violation for (i, violation) in flow_violations["branch"])
    flow_penalty = eval_piecewise_linear_penalty(max_flow_violation, penalty_block_pow_abs_max, penalty_block_pow_abs_coeff)
    
    total_penalty = power_balance_real_penalty + power_balance_imag_penalty + flow_penalty

    return total_penalty * data["baseMVA"]
end

function eval_piecewise_linear_penalty(violation, penalty_block_max, penalty_block_coeff, penalty=0)
    if length(penalty_block_max) == 0 # last block
        return penalty + penalty_block_coeff[end] * violation
    end

    if violation > penalty_block_max[1]
        cumulative = penalty_block_max[1] * penalty_block_coeff[1]
        return eval_piecewise_linear_penalty(
            violation .- penalty_block_max[1],
            penalty_block_max[2:end] .- penalty_block_max[1],
            penalty_block_coeff[2:end],
            penalty + cumulative
        )
    else
        return penalty + penalty_block_coeff[1] * violation
    end
end
