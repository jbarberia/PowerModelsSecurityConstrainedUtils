

"""
TODO: 

solution_file could be a full solution2 file, a subpart (needs to trim case.con), or None (only evaluate sol1)
"""
function evaluate_solution(solution_file_1, solution_file_2; output_file="details.csv", scenario="", return_df=false)
    input_files = get_input_files(scenario)
    evaluation = pyimport("Evaluation.test")
    evaluation.run(
        input_files.raw,
        input_files.rop,
        input_files.con,
        input_files.inl,
        sol1_name=solution_file_1,
        sol2_name=solution_file_2,
        summary_name="summary",
        detail_name=output_file,
    )
end