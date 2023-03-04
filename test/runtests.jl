using Test
using PowerModelsSecurityConstrainedUtils


@testset "Parse file" begin
    data = parse_directory("scenario_1/")
    @test data isa Dict{String,Any}
end

@testset "File handling" begin
    data = parse_directory("scenario_1/")

    solution_1 = read_solution_1(data, "scenario_1/solution1.txt")
    solution_2 = read_solution_2(data, "scenario_1/single_solution2.txt")

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