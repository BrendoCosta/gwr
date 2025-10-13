pub type Stacktrace
{
    Stacktrace(module: String, function: String, arity: Int, extrainfo: List(StacktraceExtraInfo))
}

pub type StacktraceExtraInfo
{
    Line(position: Int)
    File(path: String)
    ErrorInfo(description: String)
}

@external(erlang, "debug", "get_stacktrace")
pub fn get_stacktrace() -> List(Stacktrace)