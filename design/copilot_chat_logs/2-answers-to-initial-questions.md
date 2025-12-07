johncip: My answers:

1. (name) I'd like to call it "Super 8" which can be shorted to "super8" for file paths and the like.

2. (location) lib/super8 should be the root for now. if it works I will eventually want to make it a gem, but for now I am doing a spike and don't want to deal with the overhead of making a gem. conceptually it will be separate from the commission app.

3. (cassette storage) the storage location should be a global config value that is configurable by the user, but it should default to spec/super8_cassettes.

4. (API) I want to MVP this. to me that implies either a block style or a manual activation (and manual teardown) at first. activating with rspec metadata is very low priority. also, the basic functionality shouldn't require rspec.

5. text files on disk. I'm overall not sure of the format yet. It should be dictated by the type of data that we end up having to store.

My guess is that we'll need a file for the request/query info (or possibly one for request metadata and one for the query), plus at least one for the response.

The response might need to be saved with ruby's marshall tool. For context -- it's easier to do this with HTTP responses, because they're already text, but I suspect that the ODBC responses are typed (have real integers, real dates, etc.), though I'm not sure.

We will have to look at the internals of ruby-odbc to be sure, but if I'm right, then I think we'll need marshall or something like it -- the main requirement being that we don't lose information becuase of the choice of storage format.

Also, the response might need a separate file stored just for column headers / column definitions / info like that.

GitHub Copilot: I'll update the design document with your decisions and expand on the technical details we need to investigate.

Using "Replace String in File"


```

```


Using "Replace String in File"


```

```


Using "Replace String in File"


```

```


Using "Replace String in File"


```

```


Using "Replace String in File"


```

```
Updated the design document with your decisions. Key changes:

**Project Identity**:
- Named "Super 8" (continuing the cassette/film recording theme)
- Location: `lib/super8/`
- Default cassette storage: `spec/super8_cassettes/`

**File Format**:
- Multi-file approach per cassette with numbered sequences
- `request_N.yml` - metadata (DSN, timestamp, etc.)
- `query_N.txt` - raw SQL for easy inspection
- `columns_N.yml` - column definitions
- `response_N.marshal` - marshaled response data to preserve types

**API**:
- Block-based `Super8.use_cassette("name") { }` for MVP
- Manual `insert_cassette`/`eject_cassette` as alternative
- No RSpec dependency in core
- RSpec metadata integration deferred

**Investigation Tasks Section**:
Added priority list for next steps, focusing on understanding ruby-odbc internals to determine:
- Whether response data is typed (integers, dates) or strings
- Column metadata structure
- What needs Marshal vs YAML

The multi-file format gives you flexibility - easy to inspect queries and metadata as text, while Marshal preserves type fidelity for the response data.

What should we investigate first? I'd suggest looking at ruby-odbc internals to understand the response data structure, or we could start scaffolding the basic file structure for the library.

Made changes.
