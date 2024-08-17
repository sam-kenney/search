import gleam/dynamic
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/uri

import fmglee as fmt
import search/config
import search/error

pub type SearchResult {
  SearchResult(title: String, link: String, snippet: String)
}

pub type SearchResults {
  SearchResults(items: List(SearchResult))
}

fn search_item_decoder() {
  dynamic.decode3(
    SearchResult,
    dynamic.field("title", of: dynamic.string),
    dynamic.field("link", of: dynamic.string),
    dynamic.field("snippet", of: dynamic.string),
  )
}

fn search_items_decoder() {
  dynamic.decode1(
    SearchResults,
    dynamic.field("items", of: dynamic.list(search_item_decoder())),
  )
}

fn page_number(num: Int) -> Int {
  { num - 1 } * 10 + 1
}

fn build_url(key: String, engine_id: String, q: String, start: Int) -> String {
  fmt.new(
    "https://www.googleapis.com/customsearch/v1?key=%s&cx=%s&q=%s&start=%d",
  )
  |> fmt.s(key)
  |> fmt.s(engine_id)
  |> fmt.s(uri.percent_encode(q))
  |> fmt.d(start)
  |> fmt.build
}

fn parse_response(body: String) -> Result(List(SearchResult), error.SearchError) {
  json.decode(body, search_items_decoder())
  |> result.map(fn(r) { r.items })
  |> result.map_error(fn(e) { error.Decode(e) })
}

pub fn execute(
  q: String,
  pageno: Int,
) -> Result(List(SearchResult), error.SearchError) {
  use cfg <- result.try(config.load())

  let assert Ok(url) =
    page_number(pageno)
    |> build_url(cfg.key, cfg.id, q, _)
    |> uri.parse

  let assert Ok(req) = request.from_uri(url)
  case httpc.send(req) {
    Error(_) -> Error(error.Request)
    Ok(res) -> {
      case res.status {
        200 ->
          parse_response(res.body)
          // Lazy but haven't found a case yet where failing to decode isn't
          // because there were no results. Would've checked the status code
          // of the response but it appears to be 200 regardless of content
          |> result.replace_error(error.NoResults)
        _ -> Error(error.Auth)
      }
    }
  }
}

pub fn format(results: List(SearchResult)) -> String {
  do_format(results, [], 0)
  |> string.join("\n")
}

fn do_format(
  results: List(SearchResult),
  out: List(String),
  idx: Int,
) -> List(String) {
  case results {
    [result, ..] -> {
      do_format(
        list.drop(results, 1),
        [format_result(result, idx), ..out],
        idx + 1,
      )
    }
    [] -> list.reverse(out)
  }
}

fn format_result(res: SearchResult, idx: Int) -> String {
  fmt.new(
    "
%d | %s
    %s
    %s

    %s
  ",
  )
  |> fmt.d(idx + 1)
  |> fmt.s(res.title)
  |> fmt.s(string.repeat("-", string.length(res.title)))
  |> fmt.s(res.snippet |> wrap_text(70) |> string.join("\n    "))
  |> fmt.s(res.link)
  |> fmt.build
}

fn wrap_text(s: String, max_len: Int) -> List(String) {
  do_wrap_text(string.split(s, ""), max_len, 0, "", [])
  |> list.reverse
}

fn do_wrap_text(
  s: List(String),
  max_len: Int,
  current_len: Int,
  builder: String,
  out: List(String),
) -> List(String) {
  case s, max_len == current_len {
    [v, ..], False ->
      do_wrap_text(
        list.drop(s, 1),
        max_len,
        current_len + 1,
        string.append(builder, v),
        out,
      )
    [v, ..], True ->
      do_wrap_text(list.drop(s, 1), max_len, current_len + 1, v, [
        builder,
        ..out
      ])
    [], _ -> out
  }
}
