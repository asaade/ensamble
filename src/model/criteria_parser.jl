module CriteriaParser

export parse_criteria

using DataFrames
using StringDistances

"""
    normalize(input_str::AbstractString) -> AbstractString

Converts input string to uppercase and ensures consistent spacing around operators.
"""
function normalize(input_str::AbstractString)::AbstractString
    return uppercase(
        replace(
        input_str, r"\s*([!=<>]=|!IN|IN|\&\&|\|\|)\s*" => s" \1 ", r"\s*,\s*" => ","
    ),
    )
end

"""
    sanitize_input(input_str::AbstractString) -> AbstractString

Validates input string and throws an error if it contains invalid characters.
"""
function sanitize_input(input_str::AbstractString)::AbstractString
    if isempty(input_str)
        return input_str
    elseif !isvalidinput(input_str)
        throw(ArgumentError("Input string contains invalid characters"))
    end
    return input_str
end

"""
    isvalidinput(input_str::AbstractString) -> Bool

Checks if the input string contains only allowed characters.
"""
function isvalidinput(input_str::AbstractString)::Bool
    return match(r"^[a-zA-Z0-9\[\]\,\s\<\>\='\"\"\!\|\&\-\.]+$", input_str) !== nothing
end

# Maps operators to their corresponding functions
const OPERATOR_MAP = Dict(
    "!="  => (lhs, rhs) -> lhs .!= rhs,
    "<"   => (lhs, rhs) -> lhs .< rhs,
    "<="  => (lhs, rhs) -> lhs .<= rhs,
    "=="  => (lhs, rhs) -> lhs .== rhs,
    ">"   => (lhs, rhs) -> lhs .> rhs,
    ">="  => (lhs, rhs) -> lhs .>= rhs,
    "IN"  => (lhs, rhs) -> lhs .∈ Ref(rhs),
    "!IN" => (lhs, rhs) -> lhs .∉ Ref(rhs)
)

"""
    validate_operator(op::AbstractString)

Checks if the operator is valid.
"""
function validate_operator(op::AbstractString)
    if op ∉ keys(OPERATOR_MAP)
        throw(ArgumentError("Unsupported operator: $op"))
    end
end

"""
    suggest_similar_column(input_column::Symbol, df::DataFrame) -> AbstractString

Finds the closest matching column name in the DataFrame.
"""
function suggest_similar_column(input_column::Symbol, df::DataFrame)::AbstractString
    existing_columns = Symbol.(names(df))
    distances = [levenshtein(string(input_column), string(col)) for col in existing_columns]
    closest_match = existing_columns[argmin(distances)]
    return string(closest_match)
end

"""
    get_column(df::DataFrame, col::Symbol)

Retrieves a column from the DataFrame or suggests a similar column if it does not exist.
"""
function get_column(df::DataFrame, col::Symbol)
    if col ∉ Symbol.(names(df))
        similar_col = suggest_similar_column(col, df)
        throw(ArgumentError("Column $col does not exist. Did you mean '$similar_col'?"))
    end
    return df[!, col]
end

"""
    apply_condition(op::AbstractString, lhs::Symbol, rhs, df::DataFrame) -> Vector{Bool}

Applies a condition to a DataFrame column.
"""
function apply_condition(op::AbstractString, lhs::Symbol, rhs, df::DataFrame)
    lhs_col = get_column(df, lhs)
    return OPERATOR_MAP[op](lhs_col, rhs)
end

"""
    is_numeric(s::AbstractString) -> Bool

Checks if a string can be parsed as a number.
"""
function is_numeric(s::AbstractString)::Bool
    try
        parse(Float64, s)
        return true
    catch
        return false
    end
end

"""
    process_rhs(rhs::AbstractString) -> Union{Float64, String, Vector}

Parses the right-hand side of a condition.
"""
function process_rhs(rhs::AbstractString)::Union{Float64, AbstractString, Vector}
    if match(r"^\[.*\]$", rhs) !== nothing
        elements = map(String, split(strip(rhs, ['[', ']']), ","))
        return [is_numeric(el) ? parse(Float64, el) : strip(el, ''') for el in elements]
    elseif is_numeric(rhs)
        return parse(Float64, rhs)
    else
        return strip(rhs, '"')
    end
end

"""
    parse_condition(condition_expr::AbstractString) -> Tuple{Symbol, String, Any}

Splits condition expression into (column, operator, value).
"""
function parse_condition(condition_expr::AbstractString)::Tuple{Symbol, String, Any}
    parts = split(condition_expr, r"\s+")
    if length(parts) == 3
        lhs, op, rhs = parts
        validate_operator(op)
        return (Symbol(lhs), op, process_rhs(rhs))
    else
        throw(ArgumentError("Invalid condition format: $condition_expr"))
    end
end

"""
    handle_basic_condition(condition_expr::AbstractString) -> Function

Creates a function to apply a basic condition to a DataFrame.
"""
function handle_basic_condition(condition_expr::AbstractString)::Function
    lhs, op, rhs = parse_condition(condition_expr)
    return df -> apply_condition(op, lhs, rhs, df)
end

"""
    handle_column_only(col_expr::AbstractString) -> Function

Creates a function to select a DataFrame column.
"""
handle_column_only(col_expr::AbstractString)::Function = df -> df[!, Symbol(col_expr)]

"""
    split_outside_brackets(input_str::AbstractString) -> Tuple{AbstractString, AbstractString}

Splits input string at the first comma outside brackets.
"""
function split_outside_brackets(input_str::AbstractString)::Tuple{AbstractString, AbstractString}
    level = 0
    split_pos = nothing

    for (i, c) in enumerate(input_str)
        if c == '['
            level += 1
        elseif c == ']'
            level -= 1
        elseif c == ',' && level == 0
            split_pos = i
            break
        end
    end

    if split_pos === nothing
        return input_str, ""
    else
        return input_str[1:(split_pos - 1)], input_str[(split_pos + 1):end]
    end
end

"""
    handle_column_and_condition(col_expr::AbstractString, condition_expr::AbstractString) -> Function

Creates a function to filter a DataFrame by column and condition.
"""
function handle_column_and_condition(col_expr::AbstractString, condition_expr::AbstractString)::Function
    lhs, op, rhs = parse_condition(condition_expr)
    return df -> df[apply_condition(op, lhs, rhs, df), Symbol(col_expr)]
end

"""
    handle_logical_expression(expr::AbstractString) -> Function

Handles logical expressions by combining multiple conditions.
"""
function handle_logical_expression(expr::AbstractString)
    if contains(expr, "&&")
        conditions = split(expr, "&&")
        condition_funcs = [parse_criteria(strip(cond)) for cond in conditions]
        return df -> reduce((a, b) -> a .& b, [cond(df) for cond in condition_funcs])
    elseif contains(expr, "||")
        conditions = split(expr, "||")
        condition_funcs = [parse_criteria(strip(cond)) for cond in conditions]
        return df -> reduce((a, b) -> a .| b, [cond(df) for cond in condition_funcs])
    else
        return parse_criteria(expr)
    end
end

"""
    parse_criteria(input_str::AbstractString; max_length::Int=100) -> Function

Parses criteria string into a function that can be applied to a DataFrame.
"""
function parse_criteria(input_str::AbstractString; max_length::Int = 100)::Function
    if length(input_str) > max_length
        throw(ArgumentError("Input string exceeds maximum allowed length of $max_length characters"))
    end

    input_str = sanitize_input(strip(input_str))

    if isempty(input_str)
        return df -> trues(size(df, 1))
    end

    normalized_str = normalize(input_str)

    if contains(normalized_str, "&&") || contains(normalized_str, "||")
        return handle_logical_expression(normalized_str)
    end

    col_expr, condition_expr = split_outside_brackets(normalized_str)
    if !isempty(condition_expr)
        return handle_column_and_condition(strip(col_expr), strip(condition_expr))
    else
        parts = split(normalized_str, r"\s+")
        if length(parts) == 3
            return handle_basic_condition(normalized_str)
        elseif length(parts) == 1
            return handle_column_only(normalized_str)
        else
            throw(ArgumentError("Invalid criteria string format"))
        end
    end
end

end  # module CriteriaParser
