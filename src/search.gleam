import gleam/io
import gleam/list
import gleam/result

import argv
import search/arguments as args
import search/config
import search/error
import search/query

pub fn main() {
  case argv.load().arguments |> args.parse {
    Ok(args.WriteConfig(id, key)) ->
      config.write(id, key)
      |> result.map_error(error.describe)
      |> result.unwrap_both

    Ok(args.Search(q, p)) ->
      query.execute(q, p)
      |> result.map(query.format)
      |> result.map_error(error.describe)
      |> result.unwrap_both

    Ok(args.SearchWithLimit(q, p, n)) ->
      query.execute(q, p)
      |> result.map(fn(l) { list.take(l, n) |> query.format })
      |> result.map_error(error.describe)
      |> result.unwrap_both

    Ok(args.SearchWithOpen(..)) -> "Not implemented"
    Error(e) -> args.describe_error(e)
  }
  |> io.println
}
