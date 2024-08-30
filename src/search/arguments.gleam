import gleam/int
import gleam/result

pub type Arguments {
  ConfigWrite(id: String, key: String)
  SearchExecute(q: String, p: Int)
  SearchExecuteWithLimit(q: String, p: Int, n: Int)
  SearchExecuteWithOpen(q: String, p: Int, o: Int)
}

pub type ParseError {
  NoArguments
  Help
  LimitSize(Int)
  OpenOutOfBounds(Int)
  InvalidInt(String)
}

pub fn describe_error(e: ParseError) -> String {
  case e {
    NoArguments -> "No arguments provided"
    Help -> "Search should return the help menu"
    LimitSize(n) ->
      "The value passed to -n must be between 1 and 10, got "
      <> int.to_string(n)
    OpenOutOfBounds(o) ->
      "The value passed to -o must be between 1 and 10, got "
      <> int.to_string(o)
    InvalidInt(s) -> "Invalid Int value: " <> s
  }
}

fn validate_limit(n: String) -> Result(Int, ParseError) {
  case int.parse(n) {
    Ok(num) if num >= 1 && num <= 10 -> Ok(num)
    Ok(num) -> Error(LimitSize(num))
    _ -> Error(InvalidInt(n))
  }
}

fn validate_open(o: String) -> Result(Int, ParseError) {
  case int.parse(o) {
    Ok(open) if open >= 1 && open <= 10 -> Ok(open)
    Ok(open) -> Error(OpenOutOfBounds(open))
    _ -> Error(InvalidInt(o))
  }
}

fn parse_search_execute_with_limit(
  q: String,
  p: Int,
  n: String,
) -> Result(Arguments, ParseError) {
  use num <- result.try(validate_limit(n))
  Ok(SearchExecuteWithLimit(q, p: p, n: num))
}

fn parse_search_execute_with_open(
  q: String,
  p: Int,
  o: String,
) -> Result(Arguments, ParseError) {
  use open <- result.try(validate_open(o))
  Ok(SearchExecuteWithOpen(q, p: p, o: open - 1))
}

fn parse_search_execute_with_page(
  q: String,
  p: String,
) -> Result(Arguments, ParseError) {
  case int.parse(p) {
    Ok(page) -> Ok(SearchExecute(q, page))
    _ -> Error(InvalidInt(p))
  }
}

fn parse_search_execute_with_page_and_limit(
  q: String,
  p: String,
  n: String,
) -> Result(Arguments, ParseError) {
  use args <- result.try(parse_search_execute_with_page(q, p))
  let assert SearchExecute(q, p) = args

  use num <- result.try(validate_limit(n))
  Ok(SearchExecuteWithLimit(q, p, num))
}

fn parse_search_execute_with_page_and_open(
  q: String,
  p: String,
  o: String,
) -> Result(Arguments, ParseError) {
  use args <- result.try(parse_search_execute_with_page(q, p))
  let assert SearchExecute(q, p) = args

  use open <- result.try(validate_open(o))
  Ok(SearchExecuteWithOpen(q, p, open - 1))
}

pub fn parse(args: List(String)) -> Result(Arguments, ParseError) {
  case args {
    ["config", id, key] -> Ok(ConfigWrite(id, key))
    [q] -> Ok(SearchExecute(q, p: 1))
    [q, "-p", p] -> parse_search_execute_with_page(q, p)
    [q, "-n", n] -> parse_search_execute_with_limit(q, 1, n)
    [q, "-p", p, "-n", n] -> parse_search_execute_with_page_and_limit(q, p, n)
    [q, "-n", n, "-p", p] -> parse_search_execute_with_page_and_limit(q, p, n)
    [q, "-o", o] -> parse_search_execute_with_open(q, 1, o)
    [q, "-p", p, "-o", o] -> parse_search_execute_with_page_and_open(q, p, o)
    [q, "-o", o, "-p", p] -> parse_search_execute_with_page_and_open(q, p, o)
    [] -> Error(NoArguments)
    _ -> Error(Help)
  }
}
