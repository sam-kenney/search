// import gleam/dynamic
import envoy
import gleam/dynamic
import gleam/http/request
import gleam/httpc
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleam/uri

import argv
import fmglee as fmt
import glaml
import simplifile

pub type SearchError {
  MissingToken
  MissingId
  FileWrite(String)
  FileRead(String)
  Request
  NoHome
  Decode(json.DecodeError)
}

fn describe_error(e: SearchError) -> String {
  case e {
    MissingToken -> "Token not present in config"
    MissingId -> "Search Engine Id not present in config"
    FileWrite(s) -> "Failed to write file: " <> s
    FileRead(s) -> "Failed to read file: " <> s
    Request -> "Failed to send request"
    NoHome -> "$HOME or $HOMEPATH not set"
    Decode(e) -> {
      io.debug(e)
      "Failed to decode response"
    }
  }
}

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

pub type SearchResult {
  SearchResult(title: String, link: String, snippet: String)
}

pub type SearchResults {
  SearchResults(items: List(SearchResult))
}

pub const config_dir = ".search"

fn get_home() -> Result(String, SearchError) {
  case envoy.get("HOME"), envoy.get("HOMEPATH") {
    Ok(path), _ -> Ok(path)
    _, Ok(path) -> Ok(path)
    _, _ -> Error(NoHome)
  }
}

pub fn config_file() -> Result(String, SearchError) {
  use home <- result.try(get_home())
  Ok(home <> "/" <> config_dir <> "/config.yaml")
}

pub type Config {
  Config(id: String, key: String)
}

pub fn write(id: String, key: String) -> Result(String, SearchError) {
  use file <- result.try(config_file())
  let content =
    fmt.new("id: %s\nkey: %s\n")
    |> fmt.s(id)
    |> fmt.s(key)
    |> fmt.build

  case simplifile.write(file, content) {
    Ok(_) -> Ok("Written config to " <> file)
    Error(simplifile.Enoent) -> {
      use home <- result.try(get_home())
      case simplifile.create_directory_all(home <> "/" <> config_dir) {
        Ok(_) -> write(id, key)
        Error(e) -> Error(FileWrite(simplifile.describe_error(e)))
      }
    }
    Error(e) -> Error(FileWrite(simplifile.describe_error(e)))
  }
}

pub fn load() -> Result(Config, SearchError) {
  use file <- result.try(config_file())
  case simplifile.read(file) {
    Ok(data) -> parse_config(data)
    Error(simplifile.Enoent) ->
      Error(FileRead(
        fmt.new("no such file %s. Please run `search config`")
        |> fmt.s(file)
        |> fmt.build,
      ))
    Error(e) -> Error(FileRead(simplifile.describe_error(e)))
  }
}

fn parse_config(data: String) -> Result(Config, SearchError) {
  case glaml.parse_string(data) {
    Ok(glaml.Document(node)) -> {
      use key <- result.try(get_map_string_value(node, "key"))
      use id <- result.try(get_map_string_value(node, "id"))
      Ok(Config(id: id, key: key))
    }
    Error(e) -> Error(FileRead(e.msg))
  }
}

fn get_map_string_value(
  node: glaml.DocNode,
  name: String,
) -> Result(String, SearchError) {
  let glaml_to_search = fn(_) {
    fmt.new("Invalid config file: %s is not present")
    |> fmt.s(name)
    |> fmt.build
    |> FileRead
  }

  glaml.get(node, [glaml.Map(name)])
  |> result.map(get_yaml_string_value)
  |> result.map_error(glaml_to_search)
  |> result.flatten
}

fn get_yaml_string_value(node: glaml.DocNode) -> Result(String, SearchError) {
  case node {
    glaml.DocNodeStr(v) -> Ok(v)
    _ -> Error(FileRead("Value in config should be a String"))
  }
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

fn parse_response(body: String) -> Result(List(SearchResult), SearchError) {
  json.decode(body, search_items_decoder())
  |> result.map(fn(r) { r.items })
  |> result.map_error(fn(e) { Decode(e) })
}

pub fn query(q: String, pageno: Int) -> Result(List(SearchResult), SearchError) {
  use cfg <- result.try(load())

  let assert Ok(url) =
    uri.parse(build_url(cfg.key, cfg.id, q, page_number(pageno)))
  let assert Ok(req) = request.from_uri(url)

  let response = httpc.send(req)

  case response {
    Error(_) -> Error(Request)
    Ok(res) -> parse_response(res.body)
  }
}

pub fn format(results: List(SearchResult)) -> String {
  do_format(results, [], 0)
  |> string.join("\n")
}

fn do_format(
  results: List(SearchResult),
  builder: List(String),
  idx: Int,
) -> List(String) {
  case results {
    [result, ..] -> {
      do_format(
        list.drop(results, 1),
        [format_result(result, idx), ..builder],
        idx + 1,
      )
    }
    [] -> list.reverse(builder)
  }
}

fn format_result(res: SearchResult, idx: Int) -> String {
  let header_len = case idx {
    _ if idx < 10 -> string.length(res.title) + 4
    _ -> string.length(res.title) + 5
  }

  fmt.new("%d | %s\n%s\n\n%s")
  |> fmt.d(idx)
  |> fmt.s(res.title)
  |> fmt.s(string.repeat("-", header_len))
  |> fmt.s(res.link)
  |> fmt.build
}

pub fn main() {
  case argv.load().arguments {
    ["config", id, key] ->
      write(id, key)
      |> result.map_error(describe_error)
      |> result.unwrap_both
    [q] -> {
      query(q, 1)
      |> result.map(format)
      |> result.map_error(describe_error)
      |> result.unwrap_both
    }
    _ -> help()
  }
  |> io.println
}
