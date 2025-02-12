-module(debug).

-export_type([stacktrace/0]).
-type stacktrace() :: {
    stacktrace,
    binary(),
    binary(),
    integer(),
    list(stacktrace_extra_info())
}.

-export_type([stacktrace_extra_info/0]).
-type stacktrace_extra_info() ::
    {line, integer()} |
    {file, binary()} |
    {error_info, binary()}.

-export([get_stacktrace/0]).
-spec get_stacktrace() -> list(stacktrace()).
get_stacktrace() ->
    {current_stacktrace, FunctionCallsInfo} = erlang:process_info(erlang:self(), current_stacktrace),
    lists:filtermap(fun (Item) ->
        case Item of
            {Module, Function, Arity, ExtraInfo} ->
                ExtraInfoFiltered = lists:filtermap(fun (Info) ->
                    case Info of
                        {line, LineNo} -> {true, {line, LineNo}};
                        {file, Path} -> {true, {file, unicode:characters_to_binary(Path)}};
                        {error_info, Description} -> {true, {error_info, term_to_binary_unicode(Description)}};
                        {A, B} when is_atom(A), not is_map(B) -> false;
                        _ -> false
                    end
                end, ExtraInfo),
                {true, {stacktrace, term_to_binary_unicode(Module), term_to_binary_unicode(Function), Arity, ExtraInfoFiltered}};
            _ -> false
        end
    end, FunctionCallsInfo).

-spec term_to_binary_unicode(term()) -> binary().
term_to_binary_unicode(Term) ->
    unicode:characters_to_binary(io_lib:print(Term)).