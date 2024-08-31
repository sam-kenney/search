import gleam/int
import gleam/result

pub type Arguments {
  ConfigWrite(id: String, key: String)
  SearchExecute(query: String, page: Int)
  SearchExecuteWithLimit(query: String, page: Int, limit: Int)
  SearchExecuteWithOpen(query: String, page: Int, open: Int)
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
    LimitSize(limit) ->
      "The value passed to -n must be between 1 and 10, got "
      <> int.to_string(limit)
    OpenOutOfBounds(open) ->
      "The value passed to -o must be between 1 and 10, got "
      <> int.to_string(open)
    InvalidInt(s) -> "Invalid Int value: " <> s
  }
}

fn validate_limit(limit: String) -> Result(Int, ParseError) {
  case int.parse(limit) {
    Ok(limit) if limit >= 1 && limit <= 10 -> Ok(limit)
    Ok(limit) -> Error(LimitSize(limit))
    _ -> Error(InvalidInt(limit))
  }
}

fn validate_open(open: String) -> Result(Int, ParseError) {
  case int.parse(open) {
    Ok(open) if open >= 1 && open <= 10 -> Ok(open)
    Ok(open) -> Error(OpenOutOfBounds(open))
    _ -> Error(InvalidInt(open))
  }
}

fn parse_search_execute_with_limit(
  query: String,
  page: Int,
  limit: String,
) -> Result(Arguments, ParseError) {
  use limit <- result.try(validate_limit(limit))
  Ok(SearchExecuteWithLimit(query, page, limit: limit))
}

fn parse_search_execute_with_open(
  query: String,
  page: Int,
  open: String,
) -> Result(Arguments, ParseError) {
  use open <- result.try(validate_open(open))
  Ok(SearchExecuteWithOpen(query, page: page, open: open - 1))
}

fn parse_search_execute_with_page(
  query: String,
  page: String,
) -> Result(Arguments, ParseError) {
  case int.parse(page) {
    Ok(page) -> Ok(SearchExecute(query, page))
    _ -> Error(InvalidInt(page))
  }
}

fn parse_search_execute_with_page_and_limit(
  query: String,
  page: String,
  limit: String,
) -> Result(Arguments, ParseError) {
  use args <- result.try(parse_search_execute_with_page(query, page))
  let assert SearchExecute(query, page) = args

  use limit <- result.try(validate_limit(limit))
  Ok(SearchExecuteWithLimit(query, page, limit))
}

fn parse_search_execute_with_page_and_open(
  query: String,
  page: String,
  open: String,
) -> Result(Arguments, ParseError) {
  use args <- result.try(parse_search_execute_with_page(query, page))
  let assert SearchExecute(query, page) = args

  use open <- result.try(validate_open(open))
  Ok(SearchExecuteWithOpen(query, page, open - 1))
}

pub fn parse(args: List(String)) -> Result(Arguments, ParseError) {
  case args {
    ["config", id, key] -> Ok(ConfigWrite(id, key))
    [q] -> Ok(SearchExecute(q, page: 1))
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
