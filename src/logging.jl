module ATALogger
using Logging

const LOG_LEVELS = Dict(
    "DEBUG" => Logging.Debug,
    "INFO" => Logging.Info,
    "WARN" => Logging.Warn,
    "ERROR" => Logging.Error
)

const CURRENT_LOG_STREAM = Ref{Union{IOStream, Nothing}}(nothing)

function _close_log_stream()
    if CURRENT_LOG_STREAM[] !== nothing && isopen(CURRENT_LOG_STREAM[])
        close(CURRENT_LOG_STREAM[])
    end
    CURRENT_LOG_STREAM[] = nothing
end

function __init__()
    atexit(_close_log_stream)
end

function setup_logger(level::String = "INFO", log_file::String = "ata.log")
    _close_log_stream()
    io = open(log_file, "a")
    CURRENT_LOG_STREAM[] = io
    logger = SimpleLogger(
        io,
        get(LOG_LEVELS, uppercase(level), Logging.Info)
    )
    return global_logger(logger)
end

log_operation(operation::String, details::Dict) = @info "Operation: $operation" details...
end
