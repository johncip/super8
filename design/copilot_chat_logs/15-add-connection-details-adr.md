johncip: this is in reference to the super8 project, which is under lib/super8 and has design documents under lib/super8/design. there are also chat logs you can look at.

let's add another adr documenting what we learned about connection details using the investigation script.

ultimately I want to not gather extra connection details using get_info, because it violates expectations to have the library sending extra commands to the server, and I want that documented somewhere.

GitHub Copilot: I'll help you create an ADR documenting the decision about connection details and the investigation findings. Let me first explore the super8 project structure and existing design documents to understand the context better. 

Read [](file:///Users/john/Developer***REMOVED***/lib/super8)

Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design)

Now let me look at the existing ADR to understand the format and context: 

Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design/adr_001_single_connection_per_cassette.md#1-1), lines 1 to 50

Let me check if there are any investigation scripts or chat logs that mention connection details: 

Searched codebase for "investigation script connection details get_info", 30 results

Let me check for the chat logs to understand more about the connection details investigation: 

Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design/copilot_chat_logs)

Let me check the specific chat logs about connection details: 

Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design/copilot_chat_logs/4-add-connection-details.md#1-1), lines 1 to 50

Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design/copilot_chat_logs/5-more-connection-details-and-create-script.md#1-1), lines 1 to 120

Now let me check the investigation scripts: 

Read [](file:///Users/john/Developer***REMOVED***/lib/super8/scripts)

Let me look at the investigation scripts to understand the findings: 

Read [](file:///Users/john/Developer***REMOVED***/lib/super8/scripts/investigate_ruby_odbc.rb#1-1), lines 1 to 50

Let me also check the chat logs about what was learned: 

Searched for regex `get_info|connection details|gather extra|violates expectations` (`**/lib/super8/design/**`), 20 results

Let me read the investigations document to understand what was discovered: 

Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design/investigations.md#20-20), lines 20 to 50

Now let me check what the current implementation plan says about connection details: 

Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design/implementation_plan.md#1-1), lines 1 to 50

Now I have enough context. Based on the design documents and chat logs, I can see that the investigation revealed that `get_info` sends requests to the server, which violates expectations for a library like Super8. Let me create an ADR documenting this decision. 

Created [](file:///Users/john/Developer***REMOVED***/lib/super8/design/adr_002_avoid_extra_connection_details.md)

I've created ADR 002 that documents the decision to avoid gathering extra connection details using `get_info()`. The ADR covers:

1. **Context**: What connection metadata is available and why it might seem useful
2. **Investigation findings**: The key discovery that `get_info()` sends server requests  
3. **Problem**: Why this violates expectations for a VCR-like library
4. **Decision**: Use DSN-only for MVP to maintain transparency
5. **Consequences**: Trade-offs of this approach
6. **Future considerations**: How this could be revisited with explicit opt-in

The document emphasizes that Super8 should not make calls the code under test wouldn't make, which is a fundamental principle for recording/playback libraries. This ensures the library remains transparent and doesn't introduce unexpected side effects during recording.

Made changes.

johncip: how would the metadata provide more precise matching? we wouldn't be actually talking to the server in playback mode.

GitHub Copilot: You're absolutely right to question that. The metadata wouldn't help with playback mode validation since we're not talking to the server then.

The "more precise matching" I described would only apply during **recording mode** - to validate that the current connection matches what was previously recorded in the cassette. But even then, it's questionable whether that's actually useful.

Let me fix the ADR to clarify this and remove the misleading framing: 

Using "Replace String in File"


```

```


Using "Replace String in File"


```

```
You're right - the original framing was confusing. The metadata would only matter during recording to validate "am I recording against the same environment I intended?" But that's a much weaker use case than I initially presented, and definitely not worth violating the principle of not making unexpected server calls.

Made changes.

johncip: I wouldn't describe it as the investigation script revealing that get_info talks to the server.

For context, it's more that I wanted more connection details, and copilot went down a rabbit hole, and I didn't question the value of using get_info until the next day.

What's important here is:
- we know about get_info, and which codes to use with it, should we end up wanting those values for purely informational purposes
- it appears to us that there aren't other ways of reading these values from ruby-odbc, because as far as we can tell, it's farming things out to the odbc subsystem, so we might only know the DSN, or DSN + username
- if we want super8 to only deal strictly with what it can glean from ruby-odbc, then we need to just stick to knowing the DSN (and optionally, username)
- it might be a worthwhile future enhancement to use get_info to add richer metadata to the cassettes, but it would have to be opt-in and documented that it's not actually checked during playback



GitHub Copilot: You're right, let me reframe this to better reflect what actually happened and the reasoning: 

Using "Multi-Replace String in Files"


```

```


Using "Replace String in File"


```

```
I've rewritten the ADR to better reflect your actual discovery process and reasoning:

1. **Investigation findings** now shows the progression from wanting connection details → discovering `get_info()` → realizing it makes server calls
2. **Problem section** focuses on the principle of sticking to ruby-odbc's natural API surface rather than framing it as a "critical discovery"  
3. **Future considerations** clarifies that any `get_info()` usage would be purely informational (stored but not validated during playback)

The key insight you mentioned - that ruby-odbc farms everything out to the ODBC subsystem, so we only really have access to DSN/credentials - is now the central point rather than making it sound like we stumbled onto some hidden behavior.

Made changes.

johncip: add a small amount of sample code for how to use get_info with  a couple of those codes.

GitHub Copilot: Using "Replace String in File"


```

```


Made changes.

johncip: I'm pretty sure ruby-odbc makes these available as class constants so that you don't have to use magic numbers

GitHub Copilot: Using "Replace String in File"


```

```


Made changes.

johncip: what's this about user-controlled timing and error handling?

GitHub Copilot: Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design/adr_002_avoid_extra_connection_details.md#70-70), lines 70 to 90

You're right to question that - "user-controlled timing and error handling" is vague and doesn't really make sense in this context. If we're just gathering metadata during recording, there's no special timing control needed. Let me remove that unnecessary detail: 

Using "Replace String in File"


```

```
That was leftover text that didn't make sense. If we were to add `get_info()` calls in the future, they'd just happen during recording when the connection is established - no special timing control needed.

Made changes.

johncip: Add a note somewhere about the following -- it's not just get_info that we investigated, we also investigated using SQL commands to get the same information, both standard SQL and vendor-specific. So if we were attempting to supporting this as an opt-in feature, there are other ways beyond get_info of looking for the information.

In particular, I was interested in figuring out the schema / default library, and we had to use some ibm-specific sql.

GitHub Copilot: Using "Replace String in File"


```

```


Using "Replace String in File"


```

```


Using "Replace String in File"


```

```
I've added notes about the broader investigation into SQL-based metadata queries, including the IBM-specific SQL needed for schema/library information. This makes it clear that the decision applies to any method of gathering connection metadata that requires additional server requests, not just `get_info()`.

Made changes.

johncip: "Applications using ruby-odbc typically only use the DSN and optional credentials"

what does this mean?

GitHub Copilot: You're right to question that - it's not clear what I meant by "optional credentials" in this context.

Looking at your investigation findings, when using DSN-only connections like `ODBC.connect("retalix")`, the credentials are actually handled by the ODBC subsystem (stored in odbc.ini), not passed explicitly to ruby-odbc. So ruby-odbc itself only sees the DSN.

The line should probably just say: 

Using "Replace String in File"


```

```
That's more accurate to what your app actually does and what the investigation showed about DSN-only connections.

Made changes.

johncip: now you are asserting that people only pass the dns and don't use the explicit username form?

GitHub Copilot: You're right - I'm making an unfounded assertion. The ruby-odbc API supports both forms:

- `ODBC.connect(dsn)` - DSN-only (your usage)
- `ODBC.connect(dsn, username, password)` - explicit credentials

I don't have data on what's "typical" usage across all ruby-odbc applications. Let me fix this: 

Using "Replace String in File"


```

```
That's more accurate - the point is that ruby-odbc's API surface for connection info is limited to what you explicitly pass in, regardless of which form you use.

Made changes.

johncip: i've made some tweaks.

regarding the future considerations section -- as a weaker version of the opt-in feature, we could just encourage users to add the get_info commands themselves.

GitHub Copilot: Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design/adr_002_avoid_extra_connection_details.md#75-75), lines 75 to 95

Using "Replace String in File"


```

```
That's a good point - users who want connection metadata can just add the `get_info()` calls themselves to their application code. Super8 would record those calls like any other ODBC interaction, without needing any special configuration or complexity in the library itself.

Made changes.

johncip: that was an additional option, but you replaced the previous one with it.

GitHub Copilot: You're right - I replaced the configuration-based option instead of adding the user-driven approach as an additional alternative. Let me fix that: 

Using "Replace String in File"


```

```
Now it shows both options - the library-supported opt-in feature and the simpler user-driven approach where they just add the calls themselves.

Made changes.

johncip: the document overall feels very salesy

GitHub Copilot: You're right - the tone is overly promotional with lots of checkmarks and "✅" symbols. Let me check the current content and tone it down: 

Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design/adr_002_avoid_extra_connection_details.md#55-55), lines 55 to 70

Using "Replace String in File"


```

```


Using "Replace String in File"


```

```
That's more neutral - removed the checkmarks and toned down some of the overly enthusiastic language like "no risk" and the parenthetical about DSN-only being "the norm".

Made changes.

johncip: the project is called Super 8, not Super8

GitHub Copilot: Using "Replace String in File"


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

Searched for text `Super8 simple` (`**/lib/super8/design/adr_002_avoid_extra_connection_details.md`), no results

Searched for text `Super8` (`**/lib/super8/design/adr_002_avoid_extra_connection_details.md`), 4 results

Using "Replace String in File"


```

```


Using "Replace String in File"

Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design/adr_002_avoid_extra_connection_details.md#90-90), lines 90 to 105

It looks like some of the text may have been edited out. The remaining "Super8" references are in the code example and file paths, which should stay as "Super8" since those are actual code/file references.

Made changes.

johncip: replace the "status" area of the two ADR's with a single sentence summary of the decision.

GitHub Copilot: Using "Multi-Replace String in Files"


```

```

```

```


Made changes.

johncip: "only record the DSN argument" is incorrect. fix the summary and update the document in a way where that conclusion can't be incorrectly drawn.

GitHub Copilot: Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design/adr_002_avoid_extra_connection_details.md#1-1), lines 1 to 20

Read [](file:///Users/john/Developer***REMOVED***/lib/super8/design/adr_002_avoid_extra_connection_details.md#50-50), lines 50 to 65

I see the issue - the summary and decision text suggests Super 8 will "only record the DSN argument" when it will actually record all the ODBC calls and responses, just not gather extra connection metadata via `get_info()`. 

johncip: no. the issue is that I never said we'd throw away the username if ruby-odbc knows it.

GitHub Copilot: You're absolutely right. The decision isn't about limiting what connection info to record - it's about not using `get_info()` to gather *extra* connection details. Let me fix this: 

Using "Replace String in File"


```

```


Using "Replace String in File"


```

```


Using "Replace String in File"


```

```
Now it's clear that Super 8 will record whatever connection info is provided to `ODBC.connect()` (DSN, DSN+username+password, etc.) - the decision is specifically about not making additional `get_info()` calls to gather extra metadata.

Made changes.