# Super 8 🎞️

Record and replay ruby-odbc sessions for easier, more accurate testing.

Super 8 is a "vcr"-like library for recording and playing back ODBC interactions made with ruby-odbc, for use with automated testing. More accurate than manually mocking and less work than adding an ODBC-enabled server to your test stack.


## Installation

Add this line to your application's Gemfile:

```ruby
gem "super8", github: "johncip/super8", branch: "main"
```

Then execute:

```bash
bundle install
```


## Requirements

- Ruby 3.1 or higher
- ruby-odbc gem

I haven't tested on lower Ruby versions, but it may work.
 * It uses YAML from stdlib, which I think sets hard minimum of 1.8.
 * It uses CSV from stdlib, so for Ruby 3.4+ you will need to add `gem "csv"`.


## Usage

Configure Super8 in your test setup (e.g., `spec/spec_helper.rb`):

```ruby
require "super8"

Super8.configure do |config|
  # defaults to "spec/super8_cassettes"
  config.cassette_directory = "spec/super8_cassettes"

  # for writing cassettes, defaults to "utf8"
  config.encoding = "ibm437"
end
```

## Configuration

Use cassettes in your tests:

```ruby
RSpec.describe "ODBC stuff" do
  it "queries the database" do
    Super8.use_cassette("users/all", mode: :playback) do
      db = ODBC.connect("dsn")
      result = db.run("SELECT * FROM users")
    end
  end
end
```

Modes:
- `:record` - Records ODBC interactions to a cassette file
- `:playback` - Replays recorded interactions without connecting to the database


## Supported Methods

Currently supported ODBC methods:
- `ODBC` : `.connect`
- `ODBC::Database`: `#run`
- `ODBC::Statement`: `#fetch_all`, `#columns`, `#drop`, `#cancel`, `#close`


## Motivation

I wrote and maintain an application that communicates with the [Retalix](https://en.wikipedia.org/wiki/Retalix) ERP. I use [ruby-odbc](https://github.com/larskanis/ruby-odbc) to connect to the instance and incrementally sync a number of tables.

In testing, I would stub the ODBC parts out, which was low-level and noisy. It also meant I had to check the queries for regressions manually.

**vcr** is a library for "recording" HTTP API requests, so that they can be accurately mocked in ruby tests. It stores the request as well as the response, so that if the request made changes, it can be considered a test failure. It's also very easy to record "cassettes." I've wanted something like that for for ODBC.


## Development

This project was developed with AI assistance as an experiment in improving and documenting my workflow. The process and decisions are documented in the [design directory](design/).

* [Design docs](design/)
* [Copilot chat logs](design/copilot_chat_logs/)
* [Architecture decision records](design/decision_records/)

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).
