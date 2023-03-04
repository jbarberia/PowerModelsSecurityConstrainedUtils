"""
evaluate_solution(solution_file_1; output_file="details.csv", scenario="", return_df=false)

- Read a solution_1 file and returns it evaluation in ´output_file´
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

- Read a solution_1 and solution_2 file and return it evaluation in ´output_file´
- If return_df = true the solution is parsed as a DataFrame
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
