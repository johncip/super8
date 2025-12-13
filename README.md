# Super 8 🎞️

Record and replay ruby-odbc sessions for easier, more accurate testing.

Super 8 is a "vcr"-like library for recording and playing back ODBC interactions made with ruby-odbc, for use with automated testing. More accurate than manually mocking and less work than adding an ODBC-enabled server to your test stack.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'super8', github: 'johncip/super8', branch: 'main'
```

Then execute:

```bash
bundle install
```


## Requirements

- Ruby 3.1 or higher
- ruby-odbc gem


## Usage

Configure Super8 in your test setup (e.g., `spec/spec_helper.rb`):

```ruby
require 'super8'

Super8.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
end
```

Use cassettes in your tests:

```ruby
RSpec.describe MyODBCClient do
  it 'queries the database' do
    Super8.use_cassette('my_query', mode: :record) do
      # Your ODBC code here
      db = ODBC.connect('DSN=MyDatabase')
      result = db.run('SELECT * FROM users')
      # assertions...
    end
  end
end
```

Modes:
- `:record` - Records ODBC interactions to a cassette file
- `:playback` - Replays recorded interactions without connecting to the database


## Motivation

I wrote and maintain an application for calculating sales rep commissions based on invoice data pulled from the [Retalix](https://en.wikipedia.org/wiki/Retalix) ERP. I use [ruby-odbc](https://github.com/larskanis/ruby-odbc) to connect to the instance and incrementally sync a number of tables.

In the past, I would stub the ODBC parts out, which means that the querying side wasn't checked well for regressions. Also, the stubbing was manual and noisy:

<img width="500" alt="code screenshot" src="https://github.com/user-attachments/assets/d12b11fb-4a04-40fc-81f8-de2aa88facfb" />

**vcr** is a library for "recording" HTTP API requests, so that they can be accurately mocked in ruby tests. It stores the request as well as the response, so that if the request made changes, it can be considered a test failure. It's also very easy to record "cassettes." I've wanted something like that for for ODBC.


## Development

This project was developed with extensive AI assistance as an experiment in AI-assisted coding workflows. The process and decisions are documented in the [design directory](design/).

* [Design docs](design/)
* [Copilot chat logs](design/copilot_chat_logs/)
* [Architecture decision records](design/decision_records/)

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).
