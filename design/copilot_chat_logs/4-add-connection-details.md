johncip: One thing that makes this different from VCR's work is that the connection & authentication bits happen separately and ahead of time.

with HTTP each request/response cycle is separate. you are authorized because the headers contain a cookie with a session key or something like it. with ODBC, you create a persistent connection as a first step and then you use the connection while it's open (I think. also technically HTTP connections are persistent too, but not in a. way that matters for what I'm talking about here.)

anyway, the point is that I suspect we'll have to store connection info as part of the cassette. the connection info might itself be in the form of a request and a response.

while doing this, we should redact usernames and passwords from the stored connection info.

GitHub Copilot: Read [](file:///Users/john/Developer/Ferraro/Commission/commission_reporter/docs/super8_design.md#1-1), lines 1 to 100

Read [](file:///Users/john/Developer/Ferraro/Commission/commission_reporter/docs/super8_design.md#100-100), lines 100 to 200

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
Updated the design document to address connection handling and credential security:

**Key additions**:

1. **`connection.yml` file** - Added to cassette structure to store connection metadata separately

2. **Connection Lifecycle** - Documented how ODBC differs from HTTP:
   - Persistent connection vs independent requests
   - Authentication happens once during connection
   - Connection object used for all subsequent queries

3. **Credential Redaction** - Security requirement:
   - Usernames and passwords automatically redacted as `<USERNAME>`, `<PASSWORD>`
   - DSN name preserved for matching
   - In playback mode, no real connection made so credentials not needed

4. **New Component**: `Super8::Connection` class to handle connection metadata and redaction

5. **Investigation Tasks** - Reorganized to prioritize understanding:
   - How `ODBC.connect` accepts credentials (args vs DSN config)
   - Where credentials come from in your current setup (only DSN passed)
   - How to extract and redact them

The design now reflects that connection info is separate from query interactions, similar to how HTTP session/auth is separate from individual requests, but recorded as part of the cassette since it's needed to replay the scenario.

Made changes.

johncip: Under #7 -- I'm not 100% we'll need to record the connection details yet, i just want it there as a possibility. also I'm not sure what "**critical**" is there for, if anything this is a nice-to-have.

GitHub Copilot: Using "Replace String in File"


```

```
Removed the "**Critical**" marking and reframed connection recording as optional - noting it may not be necessary.

Made changes.