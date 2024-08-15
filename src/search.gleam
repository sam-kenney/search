import gleam/io
import gleam/list
import gleam/result

import argv
import search/arguments as args
import search/config
import search/error
import search/query

fn help() {
  "
  Usage:
    search <query> <OPTIONS>
    search config <id> <key>

  Options:
    -n\tInt\tThe number of results to list (max 10 per page)
    -o\tInt\tOpen the specified result number in your browser
    -p\tInt\tThe page number to get results from
  "
}

pub fn main() {
  case argv.load().arguments |> args.parse {
    Ok(args.ConfigWrite(id, key)) ->
      config.write(id, key)
      |> result.map_error(error.describe)
      |> result.unwrap_both

    Ok(args.SearchExecute(q, p)) ->
      query.execute(q, p)
      |> result.map(query.format)
      |> result.map_error(error.describe)
      |> result.unwrap_both

    Ok(args.SearchExecuteWithLimit(q, p, n)) ->
      query.execute(q, p)
      |> result.map(fn(l) { list.take(l, n) |> query.format })
      |> result.map_error(error.describe)
      |> result.unwrap_both

    Ok(args.SearchExecuteWithOpen(..)) -> "Not implemented"
    Error(args.NoArguments) | Error(args.Help) -> help()
    Error(e) -> args.describe_error(e)
  }
  |> io.println
}
