# Super 8 🎞️

A WIP attempt to mostly-AI-code something that works like [vcr](https://github.com/vcr/vcr), but for [ODBC](https://en.wikipedia.org/wiki/Open_Database_Connectivity) queries instead of HTTP requests, and to document the process.

* [Design docs](https://github.com/johncip/super8/tree/main/design)
* [Copilot chat logs](https://github.com/johncip/super8/tree/main/design/copilot_chat_logs)
* [Architecture decision records](https://github.com/johncip/super8/tree/main/design/decision_records)

## Motivation

I wrote and maintain an application for calculating sales rep commissions based on invoice data pulled from the [Retalix](https://en.wikipedia.org/wiki/Retalix) ERP. I use [ruby-odbc](https://github.com/larskanis/ruby-odbc) to connect to the instance and incrementally sync a number of tables.

In the past, I would stub the ODBC parts out, which means that the querying side wasn't checked well for regressions. Also, the stubbing was manual and noisy:

<img width="500" alt="code screenshot" src="https://github.com/user-attachments/assets/d12b11fb-4a04-40fc-81f8-de2aa88facfb" />

**vcr** is a library for "recording" HTTP API requests, so that they can be accurately mocked in ruby tests. It stores the request as well as the response, so that if the request made changes, it can be considered a test failure. It's also very easy to record "cassettes." I've wanted something like that for for ODBC.

## Success criteria

- [x] be able to "record" ODBC connections+queries+responses
- [x] be able to "play back" the responses
- [x] changes to tests are minimal -- basically just loading the library in
- [ ] packaged as a gem (WIP)
- [ ] (nice to have) the tool is general enough to warrant publishing on [rubygems.org](https://rubygems.org/)

## Documenting AI-assisted workflow

As a means of refining how I use these tools, the idea here is to generate as much as possible using GitHub Copilot, and to document the process. I will save the chat logs, and create artifacts, like [software design documents](https://www.atlassian.com/work-management/knowledge-sharing/documentation/software-design-document) and [architecture decision records](https://github.com/joelparkerhenderson/architecture-decision-record?tab=readme-ov-file).
