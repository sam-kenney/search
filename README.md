# search

Search Google straight from your terminal!

## Installation

To install the search CLI run the following commands:

```sh
git clone git@github.com:sam-kenney/search.git
cd search
./bin/install
```

The cli can now be used with the `search` command.

Remember to add `$HOME/.gleam/bin/` to your `$PATH`.

## Configuration

To use the search CLI, you must set up the [Google Custom Search API](https://developers.google.com/custom-search/v1/introduction)
with a [Google Cloud Project](https://cloud.google.com/?hl=en). Once this is done, take 
the search engine id and your search engine key, then run the following.

```sh
search config <id> <key>
```

This will create `$HOME/.search/config.yaml` which will store your credentials for
use with the `search` command.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
