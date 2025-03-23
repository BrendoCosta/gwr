import gleam/list
import gleam/option
import gleam/string

import gwr/execution/debug

pub opaque type ParsingError
{
    Trap(message: option.Option(String), stacktrace: List(debug.Stacktrace))
}

pub fn new() -> ParsingError
{
    Trap(message: option.None, stacktrace: debug.get_stacktrace() |> list.drop(2))
}

pub fn add_message(error: ParsingError, message: String) -> ParsingError
{
    Trap(..error, message: option.Some(message)) 
}

pub fn get_message(error: ParsingError) -> option.Option(String)
{
    error.message
}

pub fn to_error(error: ParsingError) -> Result(a, ParsingError)
{
    Error(error)
}

pub fn to_string(error: ParsingError) -> String
{
    string.inspect(error)
}