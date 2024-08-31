import gleeunit
import gleeunit/should

import search/arguments

pub fn main() {
  gleeunit.main()
}

pub fn arguments_parse_config_ok_test() {
  ["config", "a", "b"]
  |> arguments.parse
  |> should.equal(Ok(arguments.ConfigWrite(id: "a", key: "b")))
}

pub fn arguments_parse_config_invalid_args_test() {
  ["config", "b"]
  |> arguments.parse
  |> should.equal(Error(arguments.Help))
}

pub fn arguments_parse_search_ok_test() {
  ["some query"]
  |> arguments.parse
  |> should.equal(Ok(arguments.SearchExecute("some query", page: 1)))
}

pub fn arguments_parse_search_with_page_test() {
  ["some query", "-p", "3"]
  |> arguments.parse
  |> should.equal(Ok(arguments.SearchExecute("some query", page: 3)))
}

pub fn arguments_parse_search_with_invalid_page_test() {
  ["some query", "-p", "number"]
  |> arguments.parse
  |> should.equal(Error(arguments.InvalidInt("number")))
}

pub fn arguments_parse_search_with_limit_test() {
  ["some query", "-n", "3"]
  |> arguments.parse
  |> should.equal(
    Ok(arguments.SearchExecuteWithLimit("some query", page: 1, limit: 3)),
  )
}

pub fn arguments_parse_search_with_invalid_limit_test() {
  ["some query", "-n", "number"]
  |> arguments.parse
  |> should.equal(Error(arguments.InvalidInt("number")))
}

pub fn arguments_parse_search_with_out_of_bounds_limit_test() {
  ["some query", "-n", "11"]
  |> arguments.parse
  |> should.equal(Error(arguments.LimitSize(11)))
}

pub fn arguments_parse_search_with_open_test() {
  ["some query", "-o", "5"]
  |> arguments.parse
  |> should.equal(Ok(arguments.SearchExecuteWithOpen("some query", page: 1, open: 4)))
}

pub fn arguments_parse_search_with_out_of_bounds_open_test() {
  ["some query", "-o", "0"]
  |> arguments.parse
  |> should.equal(Error(arguments.OpenOutOfBounds(0)))
}

pub fn arguments_parse_seach_with_open_and_page_test() {
  ["some query", "-o", "5", "-p", "3"]
  |> arguments.parse
  |> should.equal(Ok(arguments.SearchExecuteWithOpen("some query", page: 3, open: 4)))
}

pub fn arguments_parse_search_with_limit_and_page_test() {
  ["some query", "-p", "4", "-n", "1"]
  |> arguments.parse
  |> should.equal(
    Ok(arguments.SearchExecuteWithLimit("some query", page: 4, limit: 1)),
  )
}

pub fn arguments_parse_no_arguments_test() {
  []
  |> arguments.parse
  |> should.equal(Error(arguments.NoArguments))
}

pub fn arguments_parse_invalid_input_test() {
  ["blah", "blah"]
  |> arguments.parse
  |> should.equal(Error(arguments.Help))
}
