# Super 8 Spike 🎞️

## What is this?

A documented, WIP attempt to mostly-AI-code something that works like [vcr](https://github.com/vcr/vcr), but for [ODBC](https://en.wikipedia.org/wiki/Open_Database_Connectivity) queries instead of HTTP requests.

The code will live under `lib/super8`. **Everything else in the repo is part of the client application and not relevant to super8.**

## Motivation

I use [ruby-odbc](https://github.com/larskanis/ruby-odbc) to communicate with a [Retalix](https://en.wikipedia.org/wiki/Retalix) instance, in order to incrementally sync some of its data to my app's database.

During automated testing, I stub the ODBC stuff out, but this means that my integration tests don't check the generated SQL queries for regressions. Also, the stubbing is manual and noisy:

<img width="500" alt="code screenshot" src="https://github.com/user-attachments/assets/d12b11fb-4a04-40fc-81f8-de2aa88facfb" />

**vcr** is a library for "recording" HTTP API requests, so that they can be accurately mocked in ruby tests. Once nice feature is that it stores the request along with the response, so that if the request made changes, it's considered a test failure. It's also very easy to create and update "cassettes" (the mental model is that it's either in "playback" or "record" mode, and the rest of your code doesn't change).

I'd like to have something like that for ruby-odbc.

## Success criteria

- be able to "record" ODBC connections+queries+responses
- be able to "play back" the responses
- changes to tests are minimal -- basically just loading the library in
- (nice to have) the tool is general enough to warrant publishing on [rubygems.org](https://rubygems.org/)


## Documenting AI-assisted workflow

As a means of refining how I use these tools, the idea here is to generate as much as possible using GitHub Copilot, and to document the process. I will save the chat logs, and create artifacts, like [software design documents](https://www.atlassian.com/work-management/knowledge-sharing/documentation/software-design-document) and [architecture decision records](https://github.com/joelparkerhenderson/architecture-decision-record?tab=readme-ov-file).
