import gleam/json

pub type SearchError {
  Auth
  MissingToken
  MissingId
  FileWrite(String)
  FileRead(String)
  Request
  NoHome
  Decode(json.DecodeError)
  NoResults
}

pub fn describe(e: SearchError) -> String {
  case e {
    Auth -> "Bad request. Please check your id and key in ~/.search/config.yaml"
    MissingToken -> "Token not present in config"
    MissingId -> "Search Engine Id not present in config"
    FileWrite(s) -> "Failed to write file: " <> s
    FileRead(s) -> "Failed to read file: " <> s
    Request -> "Failed to send request"
    NoHome -> "Could not determine home: $HOME or $HOMEPATH not set"
    Decode(_) -> "Failed to decode response"
    NoResults -> "No results found"
  }
}
