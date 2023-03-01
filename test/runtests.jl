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
        @test true
    end

    @testset "write c2 solution" begin
        filename = "solution_2.txt"
        data["label"] = data["gen_contingencies"][1].label
        data["delta"] = 0.0
        write_solution_2(data, filename)
        @test true

    end

    @testset "merge contingencies" begin
        filenames = ["scenario_1/single_solution2.txt", "scenario_1/single_solution2.txt"]
        merge_solutions_2(filenames, "merged_solution.txt")
        @test true
        rm("merged_solution.txt")
    end
end