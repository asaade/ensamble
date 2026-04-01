using Test
using .CriteriaParser
using DataFrames

# Sample DataFrame for testing
df = DataFrame(; AREA = [1, 2, 3, 4], ID = ["A", "B", "C", "D"], A = [0.6, 0.4, 0.9, 0.2])

# Test for normalize function
@testset "normalize" begin
    @test normalize("AREA == 1") == "AREA == 1"
    @test normalize("AREA !IN [1, 2, 3]") == "AREA !IN [1, 2, 3]"
    @test normalize("ID, AREA == 1") == "ID, AREA == 1"
end

# Test for process_rhs
@testset "process_rhs" begin
    @test process_rhs("[1, 2, 3]") == [1.0, 2.0, 3.0]
    @test process_rhs("5") == 5.0
    @test process_rhs("'A'") == "A"
end

# Test for parse_condition
@testset "parse_condition" begin
    cond = parse_condition("AREA == 1")
    @test cond == (:AREA, "==", 1.0)

    cond = parse_condition("AREA !IN [1, 2]")
    @test cond == (:AREA, "!IN", [1.0, 2.0])
end

# Test for end-to-end criteria parsing
@testset "parse_criteria" begin
    result1 = CriteriaParser.parse_criteria("AREA == 1")(df)
    @test result1 == [true, false, false, false]

    result2 = CriteriaParser.parse_criteria("AREA IN [1, 2]")(df)
    @test result2 == [true, true, false, false]

    result3 = CriteriaParser.parse_criteria("AREA !IN [1, 2]")(df)
    @test result3 == [false, false, true, true]

    result4 = CriteriaParser.parse_criteria("AREA == 1 && A > 0.5")(df)
    @test result4 == [true, false, false, false]

    result5 = CriteriaParser.parse_criteria("AREA == 1 || A > 0.5")(df)
    @test result5 == [true, false, true, false]
end
