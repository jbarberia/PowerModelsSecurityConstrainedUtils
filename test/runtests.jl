using Test
using DataFrames
using PowerModels
using PowerModelsSecurityConstrainedUtils


@testset "Parse file" begin
    data = parse_directory("scenario_1/")
    @test data isa Dict{String,Any}
end

@testset "File handling" begin
    data = parse_directory("scenario_1/")

    solution_1 = read_solution_1(data, "scenario_1/solution1.txt")
    solution_2 = read_solution_2(data, "scenario_1/single_solution2.txt")

    @testset "read single solution file" begin
        solution_2 = read_solution_2(data, "scenario_1/single_solution2.txt")
        @test length(solution_2["bus"]) == 500
        @test solution_2["label"] == "G_000272NORTHPORT31U1"
    end

    @testset "read specific solution file" begin
        solution_2 = read_solution_2(data, "scenario_1/solution2.txt", "G_000272NORTHPORT31U1")
        @test length(solution_2["bus"]) == 500
        @test solution_2["label"] == "G_000272NORTHPORT31U1"
    end

    @testset "write c1 solution" begin
        filename = "solution_1.txt"
        write_solution_1(data, filename)
        @test isfile(filename)
        rm(filename)
    end

    @testset "write c2 solution" begin
        filename = "solution_2.txt"
        data["label"] = data["gen_contingencies"][1].label
        data["delta"] = 0.0
        write_solution_2(data, filename)
        @test isfile(filename)
        rm(filename)
    end

    @testset "merge contingencies" begin
        filenames = ["scenario_1/single_solution2.txt", "scenario_1/single_solution2.txt"]
        merge_solutions_2(filenames, "merged_solution.txt")
        @test isfile("merged_solution.txt")
        rm("merged_solution.txt")
    end
end

@testset "Evaluation" begin
    @testset "base case" begin
        solution_file_1 = "scenario_1/solution1.txt"
        df = evaluate_solution(solution_file_1; output_file="details.csv", scenario="scenario_1/", return_df=true)
        @test size(df) == (1, 37)
    end

    @testset "full solution with df" begin
        solution_file_1 = "scenario_1/solution1.txt"
        solution_file_2 = "scenario_1/solution2.txt"
        df = evaluate_solution(solution_file_1, solution_file_2; output_file="details.csv", scenario="scenario_1/", return_df=true)
        @test size(df) == (725, 37)
    end

    @testset "helper function - partial solution" begin
        scenario = "scenario_1"
        solution_file = "scenario_1/single_solution2.txt"
        @test PowerModelsSecurityConstrainedUtils.is_partial_solution_2(solution_file, scenario) == true

        solution_file = "scenario_1/solution2.txt"
        @test PowerModelsSecurityConstrainedUtils.is_partial_solution_2(solution_file, scenario) == false
    end

    @testset "partial solution" begin
        solution_file_1 = "scenario_1/solution1.txt"
        solution_file_2 = "scenario_1/single_solution2.txt"
        df = evaluate_solution(solution_file_1, solution_file_2; output_file="details.csv", scenario="scenario_1/", return_df=true)
        @test size(df) == (2, 37)
        @test df[!, :ctg][2] == "G_000272NORTHPORT31U1"
    end

    rm("details.csv")
end

@testset "Dataframe creation" begin
    data = parse_directory("scenario_1/")
    df = to_dataframe(data["bus"])
    @test df isa DataFrame
    @test size(df) == (500, 15)
end

@testset "functions to compute evaluation" begin
    data = parse_directory("scenario_1/")
    solution_1 = read_solution_1(data, "scenario_1/solution1.txt")
    update_data!(data, solution_1)

    @testset "violations" begin
        bounds_violations = compute_bounds_violations(data)
        flow_violations = compute_flow_violations(data)
        in_service_branch = filter(x -> x.second["br_status"] != 0, data["branch"])
        @test length(flow_violations["branch"]) == length(in_service_branch)
    end

    @testset "power balance" begin
        power_balance_violations = compute_power_balance_violations(data)
        max_p_delta = maximum([abs(bus["p_delta"]) for (i, bus) in power_balance_violations["bus"]])
        max_q_delta = maximum([abs(bus["q_delta"]) for (i, bus) in power_balance_violations["bus"]])
        @test max_p_delta <= 1e-4
        @test max_q_delta <= 1e-4
    end

    @testset "contingency power balance" begin
        data = parse_directory("scenario_1/")
        contingency = data["gen_contingencies"][1]
        solution_2 = read_solution_2(data, "scenario_1/single_solution2.txt")
        update_data!(data, solution_2)
        data["gen"]["$(contingency.idx)"]["gen_status"] = 0
        power_balance_violations = compute_power_balance_violations(data)
        max_p_delta = maximum([(abs(bus["p_delta"]), i) for (i, bus) in power_balance_violations["bus"]])
        @test isapprox(max_p_delta[1], 0.000484273323150041)
        @test max_p_delta[2] == "491"
        max_q_delta = maximum([(abs(bus["q_delta"]), i) for (i, bus) in power_balance_violations["bus"]])
        @test isapprox(max_q_delta[1], 0.0463901557016563)
        @test max_q_delta[2] == "413"
    end

    @testset "inner function piecewise linear" begin
        @test PowerModelsSecurityConstrainedUtils.eval_piecewise_linear_penalty(2, [3, 6], [1, 2, 5]) == 2
        @test PowerModelsSecurityConstrainedUtils.eval_piecewise_linear_penalty(5, [3, 6], [1, 2, 5]) == 7
        @test PowerModelsSecurityConstrainedUtils.eval_piecewise_linear_penalty(10, [3, 6], [1, 2, 5]) == 29
    end

    @testset "compute penalty base case" begin
        data = parse_directory("scenario_1/")
        solution_1 = read_solution_1(data, "scenario_1/solution1.txt")
        update_data!(data, solution_1)
        penalty = compute_penalty(data)
        @test isapprox(penalty, 0.0948 * 2 / 10, atol=0.01) # el dividido 10 no se porque esta
    end

    @testset "compute penalty contingency" begin
        data = parse_directory("scenario_1/")
        contingency = data["gen_contingencies"][1]
        solution_2 = read_solution_2(data, "scenario_1/single_solution2.txt")
        update_data!(data, solution_2)
        data["gen"]["$(contingency.idx)"]["gen_status"] = 0
        penalty = compute_penalty(data)
        @show penalty
        @test isapprox(penalty / 742, 28.23 * 2 / 10, atol=1.00) # el dividido 10 no se porque esta
    end
end
