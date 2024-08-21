import gleam/result

import envoy
import fmglee as fmt
import glaml
import search/error
import simplifile

pub const config_dir = ".search"

fn get_home() -> Result(String, error.SearchError) {
  case envoy.get("HOME"), envoy.get("HOMEPATH") {
    Ok(path), _ -> Ok(path)
    _, Ok(path) -> Ok(path)
    _, _ -> Error(error.NoHome)
  }
}

pub fn config_file() -> Result(String, error.SearchError) {
  use home <- result.try(get_home())
  fmt.new("%s/%s/config.yaml")
  |> fmt.s(home)
  |> fmt.s(config_dir)
  |> fmt.build
  |> Ok
}

pub type Config {
  Config(id: String, key: String)
}

pub fn write(id: String, key: String) -> Result(String, error.SearchError) {
  use file <- result.try(config_file())
  let content =
    fmt.new("id: %s\nkey: %s\n")
    |> fmt.s(id)
    |> fmt.s(key)
    |> fmt.build

  case simplifile.write(file, content) {
    Error(simplifile.Enoent) -> {
      use _ <- result.try(create_config_dir())
      write(id, key)
    }
    Error(e) -> Error(error.FileWrite(simplifile.describe_error(e)))
    Ok(_) -> Ok("Written config to " <> file)
  }
}

fn create_config_dir() -> Result(Nil, error.SearchError) {
  use home <- result.try(get_home())
  simplifile.create_directory_all(home <> "/" <> config_dir)
  |> result.map_error(fn(e) { error.FileWrite(simplifile.describe_error(e)) })
}

pub fn load() -> Result(Config, error.SearchError) {
  use file <- result.try(config_file())
  case simplifile.read(file) {
    Error(simplifile.Enoent) -> {
      fmt.new("no such file %s. Please run `search config <id> <key>`")
      |> fmt.s(file)
      |> fmt.build
      |> error.FileRead
      |> Error
    }
    Error(e) -> Error(error.FileRead(simplifile.describe_error(e)))
    Ok(data) -> parse_config(data)
  }
}

fn parse_config(data: String) -> Result(Config, error.SearchError) {
  case glaml.parse_string(data) {
    Ok(glaml.Document(node)) -> {
      use key <- result.try(get_map_string_value(node, "key"))
      use id <- result.try(get_map_string_value(node, "id"))
      Ok(Config(id: id, key: key))
    }
    Error(e) -> Error(error.FileRead(e.msg))
  }
}

fn get_map_string_value(
  node: glaml.DocNode,
  name: String,
) -> Result(String, error.SearchError) {
  let err =
    fmt.new("Invalid config file: %s is not present")
    |> fmt.s(name)
    |> fmt.build
    |> error.FileRead

  glaml.get(node, [glaml.Map(name)])
  |> result.map(get_yaml_string_value)
  |> result.replace_error(err)
  |> result.flatten
}

fn get_yaml_string_value(
  node: glaml.DocNode,
) -> Result(String, error.SearchError) {
  case node {
    glaml.DocNodeStr(v) -> Ok(v)
    _ -> Error(error.FileRead("Value in config should be a String"))
  }
}
