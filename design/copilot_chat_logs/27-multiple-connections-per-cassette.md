User: I need to start looking at what it would take to make super8 support multiple connections per cassette, because I need to use super8 to test a sync service that calls my odbc client to sync multiple tables, and treats each table as a separate odbc session.

I want to discuss the details, starting with larger ideas first, in order to make a decision that we can document everything about in an ADR.

To start, here are some properties that I think the solution will have, but everything is up for debate (the real requirement is to capture what we need to & in a way that we can be behavior-preserving w/r/t the code that super8 is decorating, and the rest is details).

My initial thoughts were:

- ODBC.connect isn't special, it's just a command, and the logged result is a database object, and we keep track of which db object goes with which connect call, similarly to how we handle the "handoff" from database object to statement object
- one connection per file set, with files perhaps prefixed by an increasing integer connection index, and the DSN, in that order (can we do better? can we instead do something where the query is hashed, so that the order of the queries in the cassette doesn't matter?)
- no connection.yml, the only separate files will be the broken out query results

basically, what do we need to change in order to support multiple connections per cassette well?

GitHub Copilot: I'll help you explore this design question. Let me first understand the current architecture by reading the relevant design documents and code. 

Read [](file:///Users/john/Developer/Super8/super8/design/decision_records/adr_001_single_connection_per_cassette.md)

Read [](file:///Users/john/Developer/Super8/super8/design/cassette_schema.md#1-1), lines 1 to 100

Read [](file:///Users/john/Developer/Super8/super8/lib/super8/cassette.rb)

Now let me look at the wrapper implementations to understand how the object tracking currently works: 

Read [](file:///Users/john/Developer/Super8/super8/lib/super8/recording_database_wrapper.rb)

Read [](file:///Users/john/Developer/Super8/super8/lib/super8/playback_database_wrapper.rb)

Now let me check how `ODBC.connect` is currently intercepted: 

Searched for regex `ODBC.connect|connect.*cassette` (`**/lib/**/*.rb`), 1 result

Read [](file:///Users/john/Developer/Super8/super8/lib/super8.rb)

Perfect! Now I have a good understanding of the current architecture. Let me discuss the design options with you.

## Current Architecture

The current design treats `ODBC.connect` as special - it's intercepted at the module level, and there's exactly one connection per cassette. The DSN is stored in `connection.yml`, and all commands assume a single database context.

## Design Discussion

Your instinct is spot-on: **treating `connect` as just another command** is the most flexible approach. Here are the key questions and tradeoffs:

### 1. Connection Identity & Tracking

**Question:** How do we track which database object corresponds to which connection?

**Options:**
- **A) Connection ID in every command** (like your statement_id pattern)
  - Commands would have `connection_id: conn_0` alongside `statement_id: stmt_0`
  - Clean separation of concerns
  - Easy to understand when reading cassettes

- **B) Implicit tracking via command order** 
  - Assumes sequential execution, no interleaving
  - Simpler format but more fragile
  
**Recommendation:** Option A. It's consistent with your existing statement tracking pattern and makes the cassette self-documenting.

### 2. File Organization

**Question:** How should we organize row data files when there are multiple connections?

**Your proposal:** `rows_<connection_index>_<query_index>.csv`

**Alternative options:**

- **A) Flat numbering** (current): `rows_0.csv`, `rows_1.csv`...
  - Pro: Simpler, order-independent already
  - Pro: The command references the file, so connection is implicit
  - Con: Loses at-a-glance connection grouping

- **B) Connection prefix**: `rows_conn0_0.csv`, `rows_conn1_0.csv`...
  - Pro: Easy to see which rows belong to which connection
  - Con: More complex naming scheme
  - Con: Redundant since the command already specifies connection_id

- **C) Subdirectories**: `conn_0/rows_0.csv`, `conn_1/rows_0.csv`
  - Pro: Cleanest organization for many connections
  - Con: More complex directory structure
  - Con: Probably overkill for most use cases

**Recommendation:** Keep flat numbering (option A). The command references tell you everything, and the filename is just an implementation detail. This is the least disruptive change.

### 3. Hash-based vs Order-based Matching

**Question:** Should we match connections by content hash instead of order?

**Tradeoffs:**

**Order-based (current approach):**
- Pro: Simple, explicit sequencing
- Pro: Easier to debug - order in cassette matches order in code
- Pro: Can handle identical queries at different times differently
- Con: Test must call connections in exact same order

**Hash-based:**
- Pro: Order-independent - great for parallel connections
- Pro: Natural deduplication if same DSN connected multiple times
- Con: Hash collisions possible (though unlikely with DSN strings)
- Con: Loses temporal information
- Con: Can't distinguish between two calls to same DSN at different times

**Hybrid approach:**
- Commands still have order/index
- But we could add optional `connection_key` based on DSN hash for validation/debugging

**Recommendation:** Start with order-based. Your use case (sync service with multiple tables) sounds sequential, not parallel. Order-based is simpler and matches your current pattern. If you need hash-based later, it's a relatively contained change.

### 4. Connection.yml Migration

**Question:** What happens to `connection.yml`?

**Options:**

- **A) Eliminate it entirely**
  - Connection metadata moves into commands.yml as `connect` commands
  - Pro: Single source of truth
  - Pro: Supports multiple connections naturally
  - Con: Breaking change for existing cassettes

- **B) Keep it for single-connection cassettes, optional for multi**
  - Pro: Backward compatible
  - Pro: Single-connection cassettes stay simple
  - Con: Two formats to maintain

- **C) Keep it but make it a list**
  - `connection.yml` becomes array of connection configs
  - Pro: Keeps connection metadata separate
  - Con: Duplicates information in commands.yml
  - Con: Synchronization issues

**Recommendation:** Option A - eliminate `connection.yml`. Put connection info directly in commands:

```yaml
- method: connect
  connection_id: conn_0
  dsn: server_a
  result:
    server: db.example.com
    database: PROD_DB
    user_hash: a1b2c3d4...
```

This makes the cassette format fully self-contained and uniform.

### 5. Wrapper Architecture

**Current:** One `RecordingDatabaseWrapper` instance per `use_cassette` call

**With multiple connections:** Need to track multiple wrapper instances

**Options:**

- **A) Connection registry in the cassette**
  - Cassette maintains `@connections = {}`
  - Maps Ruby object_id → connection_id
  - Wrappers look up their connection_id from the registry

- **B) Wrapper knows its own connection_id**
  - Each wrapper stores its `connection_id` at creation time
  - Simpler, no global registry needed

**Recommendation:** Option B. The wrapper should know its identity. On record, assign `conn_N` at connect time. On playback, read `conn_N` from the `connect` command.

## Proposed Changes Summary

Here's what I'd recommend changing:

1. **commands.yml**: Add `connection_id` field to all commands that need it
2. **Eliminate connection.yml**: Move that data into a `connect` command
3. **Wrapper tracking**: Each wrapper knows its `connection_id`
4. **Row files**: Keep flat numbering - `rows_0.csv`, `rows_1.csv`
5. **Order-based**: Commands execute in sequence, no hash-based matching (for now)

### Example cassette format:

```yaml
- method: connect
  connection_id: conn_0
  dsn: server_a
  result:
    server: db.example.com
    database: PROD_DB
    user_hash: a1b2c3d4...

- method: connect
  connection_id: conn_1
  dsn: server_b
  result:
    server: db2.example.com
    database: PROD_DB2
    user_hash: a1b2c3d4...

- method: run
  connection_id: conn_0
  sql: "SELECT * FROM table1"
  params: []
  statement_id: stmt_0

- method: run
  connection_id: conn_1
  sql: "SELECT * FROM table2"
  params: []
  statement_id: stmt_1
```

## Questions for You

1. **Use case confirmation**: Your sync service - does it open connections sequentially or potentially in parallel?
2. **Scope**: Do you need to support the same DSN being connected multiple times in one cassette?
3. **Migration**: Do you have existing cassettes you need to keep working, or are you okay with a breaking change?
4. **Close/disconnect**: Do you need to track connection close events, or is it okay if connections are only implicitly closed at block end?

What are your thoughts on these recommendations?

User: your option B isn't a prefix. I was thinking more like "[connection-prefix]_[statement-prefix]_rows.csv"

GitHub Copilot: Ah, you're right - I misunderstood your proposal. You're suggesting filenames like:

- `conn0_stmt0_rows.csv`
- `conn0_stmt1_rows.csv`  
- `conn1_stmt0_rows.csv`

So the filename itself encodes both the connection and statement identity.

## File Naming Reconsideration

Let me reconsider the options:

**A) Flat sequential numbering** (current): `rows_0.csv`, `rows_1.csv`, `rows_2.csv`...
- Pro: Simplest - just increment a counter
- Pro: Already implemented
- Pro: The command that references it has all the context anyway
- Con: Filename alone tells you nothing about which connection/statement

**B) Connection + Statement prefix**: `conn0_stmt0_rows.csv`, `conn1_stmt2_rows.csv`
- Pro: Self-documenting - filename tells you exactly what it is
- Pro: Easy to grep/filter files by connection
- Pro: Human-readable when browsing cassette directory
- Con: More complex naming logic
- Con: Redundant with info in commands.yml
- Con: If statement_id format changes, filenames need to change too

**C) Subdirectories**: `conn_0/stmt_0_rows.csv`
- Pro: Best organization for many connections with many statements each
- Pro: Easy to delete all data for one connection
- Con: Most complex to implement
- Con: Probably overkill

**D) Just connection prefix**: `conn0_rows_0.csv`, `conn1_rows_0.csv`
- Pro: Groups by connection but keeps statement numbering simple
- Pro: Simpler than full encoding
- Con: Still redundant with commands.yml

## My Thoughts

The key question is: **What value does encoding in the filename provide?**

Arguments for self-documenting filenames (your proposal B):
- Makes cassettes easier to understand when browsing
- Could help with debugging - "oh, conn1_stmt2 has the problem"
- Future tooling could parse filenames without parsing YAML

Arguments against:
- The commands.yml already contains this mapping via `rows_file` references
- Creates a tighter coupling - if you want to renumber connections, you have to rename files
- The filename is an implementation detail - the "API" is the command that references it

## Questions

1. **How often do you manually browse cassette directories?** If you frequently look at the files directly to debug, self-documenting names are worth it.

2. **Do connection/statement IDs ever need to be renumbered?** With simple sequential numbering, you could renumber rows files independently of IDs. With encoded names, they're coupled.

3. **Is there value in making the cassette format more human-friendly vs. machine-friendly?** The original design put rows in separate files specifically for diffability and readability.

**My lean:** I still prefer flat numbering (option A) for simplicity, but I could be convinced otherwise. If you find yourself frequently browsing cassette directories and wanting to understand what each file is without opening commands.yml, then option B (`conn0_stmt0_rows.csv`) makes sense.

What's your workflow like? Do you expect to be manually inspecting cassette contents often?

User: - no subdirectories for cassettes if we can help it
- the value that the encoding should provide is that it's easier at a glance for a human reviewer to guess what's in each file

GitHub Copilot: Got it. That makes sense - cassettes are meant to be reviewed (in diffs, in PRs), so human-readability is a feature, not just a nice-to-have.

**Decision: Use connection + statement encoding in filenames**: `conn0_stmt0_rows.csv`

This aligns with your design philosophy that cassettes should be:
- Readable
- Diffable  
- Self-documenting

The redundancy with commands.yml is fine - it's no different than having both the SQL text and the rows in the cassette. You're optimizing for the human reviewer who's browsing the directory or reviewing a PR.

---

## Back to the Bigger Questions

So our emerging design is:

✅ **File naming**: `conn0_stmt0_rows.csv` (self-documenting)  
✅ **No subdirectories**: Keep flat structure  
✅ **Connection as command**: `connect` is a regular command in commands.yml  
✅ **Order-based**: Sequential execution, no hash-based matching  
✅ **Eliminate connection.yml**: Connection info goes in `connect` commands  
✅ **Connection tracking**: Add `connection_id` field to commands that need it

## Still to decide:

1. **Your use case**: Does your sync service open connections sequentially or could they be parallel/interleaved? (This matters for whether we need to support interleaved commands from multiple connections)

2. **Same DSN multiple times**: Can the same DSN be connected to multiple times in one cassette? If yes, they'd get different connection_ids (conn_0, conn_1) even though DSN is the same.

3. **Migration strategy**: 
   - Break existing cassettes (they'd need regeneration)?
   - Support both formats during transition?
   - Don't care since this is early development?

4. **Close/disconnect tracking**: Should we record when connections are closed, or assume they close at the end of the `use_cassette` block?

What are your answers on these? Then we can write up the ADR.

User: what redundancy with commands.yml?

GitHub Copilot: You're right to question that. Let me clarify what I meant by "redundancy":

In commands.yml, you'd have:
```yaml
- method: fetch_all
  connection_id: conn_0
  statement_id: stmt_0
  rows_file: conn0_stmt0_rows.csv
```

The connection and statement IDs appear **twice**:
1. As fields in the command: `connection_id: conn_0`, `statement_id: stmt_0`
2. Encoded in the filename: `conn0_stmt0_rows.csv`

Technically, you only *need* the information once - the filename could just be an opaque reference like `rows_42.csv`, and the command fields tell you everything. That's what I meant by redundancy.

But you're paying for that redundancy **intentionally** to get human-readability. Someone looking at the cassette directory sees `conn0_stmt0_rows.csv` and immediately knows what it is, without having to search through commands.yml to find which command references it.

It's the same reasoning as why SQL is stored in commands.yml even though you could just reference an external file - you want the cassette to be self-documenting.

Does that make sense? The redundancy exists, but it's a good tradeoff for readability.

User: I was imagining that there won't just be one commands file because we have to support multiple sessions.

so, conn_0_commands.yml & conn_0_stmt_0_rows.csv

GitHub Copilot: Ah! That's a **completely different design** than what I was thinking. You want:

- `conn_0_commands.yml`
- `conn_1_commands.yml`
- `conn_0_stmt_0_rows.csv`
- `conn_1_stmt_0_rows.csv`

## Implications

This design treats each connection as **independent** with its own command log. That's elegant in many ways!

**Pros:**
- No `connection_id` field needed on every command (it's implicit from which file)
- Each connection's history is self-contained and easy to read
- Very clean separation of concerns
- Natural organization for the "multiple sessions" mental model

**Cons:**
- **Loses global temporal ordering** - you can't see that "conn_1 query happened between conn_0 query 1 and query 2"
- More complex playback if commands need to interleave

## Critical Question

**Can commands from different connections interleave?**

**Scenario A - Sequential (no interleaving):**
```ruby
ODBC.connect(dsn_a) do |db1|
  db1.run("SELECT * FROM table1")
  # ... all db1 operations ...
end

ODBC.connect(dsn_b) do |db2|
  db2.run("SELECT * FROM table2")
  # ... all db2 operations ...
end
```
✅ Separate files work perfectly

**Scenario B - Interleaved:**
```ruby
db1 = ODBC.connect(dsn_a)
db2 = ODBC.connect(dsn_b)

db1.run("SELECT * FROM table1")
db2.run("SELECT * FROM table2")  
db1.run("SELECT * FROM table3")  # depends on db2 result!
```
❌ Separate files lose the ordering - playback won't know to alternate

## If you need interleaving support:

You'd need a **top-level index** to track connection order:

`cassette.yml`:
```yaml
connections:
  - connection_id: conn_0
    dsn: server_a
    commands_file: conn_0_commands.yml
  - connection_id: conn_1
    dsn: server_b
    commands_file: conn_1_commands.yml
```

Or, you keep a single `commands.yml` with all commands in global order (my original assumption).

## Questions for you:

1. **Does your sync service need interleaved commands** (db1 query, db2 query, db1 query), or are connections fully sequential?
2. If connections are sequential, do you care about preserving which order they were opened in?
3. Would you ever need to replay only one connection from a multi-connection cassette?

The answer here determines whether separate command files per connection works or whether you need global ordering.

User: In my current usage, there is no interleaving. but I was imaginging that playack happening in the right order would be independent of how it's stored -- we have unique keys on everything, the playback should fetch the right info

GitHub Copilot: Ah! That's a **key architectural insight**. You're separating:
- **Storage format** (how cassettes are organized on disk)
- **Playback mechanism** (how commands are matched during replay)

Current implementation is **sequential/ordered**: "Give me the next command"

You're proposing **keyed/lookup-based**: "Give me the command where connection_id=conn_1, method=run, sql=X"

This is more like HTTP cassette libraries (VCR) that match by request properties rather than strict order.

## Implications

**Benefits:**
- Order-independent playback (more flexible tests)
- Storage format doesn't matter - one file or many, playback logic is the same
- Natural support for interleaving without special handling

**Challenges:**
- **Matching complexity**: What makes two `run` calls "the same"?
  - SQL text must match exactly? 
  - Params must match?
  - What about `fetch` - match by position in result set?
  
- **Duplicate queries**: If the same SQL is run twice on same connection, how do we distinguish?
  - Counter/index per unique key?
  - Return first unused match?
  - Error if ambiguous?

- **Statement lifecycle**: Statement IDs are assigned during `run`, but `fetch` needs to reference them
  - Need mapping: `(connection_id, sql) → statement_id`?

## Questions

1. **Matching strategy for queries**: Should two `run` calls match if they have identical SQL+params? Or do we need additional context (like call order/index)?

2. **Duplicate handling**: If `db.run("SELECT * FROM users")` is called twice in a test, should:
   - Both calls return the same recorded result?
   - First call returns first recording, second returns second recording?
   - Error because it's ambiguous?

3. **Statement references**: After `stmt = db.run(sql)`, later `stmt.fetch()` calls need to find the right recorded data. How do we match fetch calls to statements?

Understanding your vision here will help design the right lookup mechanism. What's your thinking?

User: ok, so the things you're asking go away if we put everything about a session in one commands file?

GitHub Copilot: Yes! If each connection has sequential commands in its own file, then:

✅ **No complex matching** - just "next command" within that connection  
✅ **Duplicates handled naturally** - they're in order  
✅ **Statement lifecycle preserved** - within each connection's sequence  

The only thing you need is a **connection index** so playback knows:
- "This is the 1st connect call → use conn_0_commands.yml"
- "This is the 2nd connect call → use conn_1_commands.yml"

So you'd need something like:

**cassette.yml** (or similar):
```yaml
connections:
  - connection_id: conn_0
    dsn: server_a
  - connection_id: conn_1
    dsn: server_b
```

Then each connection file is just a sequential list:

**conn_0_commands.yml**:
```yaml
- method: run
  sql: "SELECT * FROM table1"
  statement_id: stmt_0
  
- method: fetch_all
  statement_id: stmt_0
  rows_file: conn_0_stmt_0_rows.csv
```

**conn_1_commands.yml**:
```yaml
- method: run
  sql: "SELECT * FROM table2"
  statement_id: stmt_0  # can reuse stmt_0 since it's per-connection
  
- method: fetch_all
  statement_id: stmt_0
  rows_file: conn_1_stmt_0_rows.csv
```

This keeps the simple sequential playback model you have now, just per-connection instead of global.

Is this the design you're envisioning?

User: I thought you were asking about what happens if multiple connections are opened and commands alternate between the connections? how does putting each connection's commands in a separate file preserve the lifecycle "naturally"? either I am completely lost or you just said the complete opposite of how the storage decision affects playback.

GitHub Copilot: You're right - I'm confusing myself. Let me untangle this:

## Two separate concerns:

**1. Statement lifecycle within a connection:**
```ruby
stmt = db.run("SELECT * FROM users")  # Creates stmt_0
rows = stmt.fetch_all()                # Uses stmt_0
```
This is preserved **within each connection's sequential command list**, regardless of whether connections are in one file or many.

**2. Global interleaving across connections:**
```ruby
db1.run("SQL A")    # Connection 1, timestamp T1
db2.run("SQL B")    # Connection 2, timestamp T2  
db1.run("SQL C")    # Connection 1, timestamp T3
```

Separate files per connection **lose** the global ordering (T1, T2, T3).

## Your statement about "playback independent of storage"

When you said "playback should fetch the right info" using keys, you mean:

- Playback doesn't care about order
- When the code calls `db1.run("SQL A")`, playback looks up: connection=conn_0, method=run, sql="SQL A"
- It finds the matching command regardless of file organization

So separate files per connection **do work** with keyed lookup because you're not relying on order anyway.

But here's my confusion: if you're not using keyed lookup, and you're using sequential "next command" playback (like current implementation), then separate files **don't** work for interleaving.

**Question:** Are you saying you want to switch to keyed lookup playback, or keep sequential playback? That's what determines if separate files make sense.

User: when I said that we could juse the keys to look up, I was forgetting that we're relying on the order to be able to verify that the calling code hasn't changed what order it sends commands in.

step back a level, here's my issue -- I make separate connections/sessions, which are not interleaved, but which might happen in a random order, because they're independent.

but it occurs to me that, if the user did make separate connections, and interleave the commands, then we shouldn't store in a way that loses that info.

thoughts?

GitHub Copilot: Ah! Now I understand your constraint:

**Requirement:** Don't lose information. If interleaving happens, the cassette should preserve it, even if you don't need it today.

**Problem with separate files per connection:** You lose the global temporal order. You can't tell if commands were interleaved or not.

**Solution:** Keep a single `commands.yml` with all commands from all connections, with `connection_id` on each command.

```yaml
- method: connect
  connection_id: conn_0
  dsn: server_a

- method: connect
  connection_id: conn_1
  dsn: server_b

- method: run
  connection_id: conn_0
  sql: "SELECT * FROM table1"
  statement_id: stmt_0

- method: run
  connection_id: conn_1
  sql: "SELECT * FROM table2"
  statement_id: stmt_0  # Note: stmt_0 on conn_1, different from stmt_0 on conn_0

- method: fetch_all
  connection_id: conn_0
  statement_id: stmt_0
  rows_file: conn_0_stmt_0_rows.csv
```

This way:
- ✅ Preserves global order (can see interleaving if it happens)
- ✅ Each connection's sequential flow is preserved via `connection_id` + order
- ✅ Playback validates order hasn't changed
- ✅ File names are still human-readable: `conn_0_stmt_0_rows.csv`

The only thing we lose vs separate files is the visual grouping, but that's fine - the `connection_id` field provides the grouping.

Does this resolve it? Single `commands.yml`, add `connection_id` field, eliminate `connection.yml`?

User: I think so. what does the overall file storage scheme become?

GitHub Copilot: ## File Storage Scheme

```
cassettes/
  <cassette_name>/
    commands.yml
    conn_0_stmt_0_rows.csv
    conn_0_stmt_1_rows.csv
    conn_1_stmt_0_rows.csv
    conn_1_stmt_1_rows.csv
    ...
```

### commands.yml structure:

```yaml
# First connection
- method: connect
  connection_id: conn_0
  dsn: server_a
  result:
    server: db.example.com
    database: PROD_DB
    user_hash: a1b2c3d4e5f6...
    schema: APP_DATA

# Second connection
- method: connect
  connection_id: conn_1
  dsn: server_b
  result:
    server: db2.example.com
    database: PROD_DB2
    user_hash: a1b2c3d4e5f6...
    schema: OTHER_SCHEMA

# Commands can interleave
- method: run
  connection_id: conn_0
  sql: "SELECT * FROM table1"
  params: []
  statement_id: stmt_0

- method: run
  connection_id: conn_1
  sql: "SELECT * FROM table2"
  params: []
  statement_id: stmt_0

- method: columns
  connection_id: conn_0
  statement_id: stmt_0
  result:
    - name: ID
      type: 4
      length: 10

- method: fetch_all
  connection_id: conn_0
  statement_id: stmt_0
  rows_file: conn_0_stmt_0_rows.csv

- method: fetch_all
  connection_id: conn_1
  statement_id: stmt_0
  rows_file: conn_1_stmt_0_rows.csv

- method: drop
  connection_id: conn_0
  statement_id: stmt_0
  result: null
```

### Key changes from current:

1. **No `connection.yml`** - connection metadata moves into `connect` commands
2. **`connection_id` field** - added to all commands (except `connect`, which establishes the ID)
3. **Row file naming** - `conn_X_stmt_Y_rows.csv` instead of `rows_N.csv`
4. **Global ordering** - all connections' commands in one file, temporal order preserved
5. **`connect` is a command** - treated like any other method call, not special

### Notes:
- Statement IDs are scoped per-connection (conn_0 can have stmt_0, conn_1 can also have stmt_0)
- Connection IDs are sequential: conn_0, conn_1, conn_2...
- Commands execute in order, but `connection_id` lets you track which connection each belongs to
- Row files are self-documenting from their filename alone

Does this capture what you envisioned?

User: I think if we stick to the prefix thing then it becomes possible for the sort order of the rows filenames to not match the order that they appear in the commands.yml, right?

GitHub Copilot: Yes! Great catch. With interleaving, alphabetical sort doesn't match temporal order.

Example:
```yaml
# commands.yml order:
- fetch_all: conn_0_stmt_0_rows.csv  # 1st
- fetch_all: conn_1_stmt_0_rows.csv  # 2nd  
- fetch_all: conn_0_stmt_1_rows.csv  # 3rd
- fetch_all: conn_1_stmt_1_rows.csv  # 4th
```

Alphabetically sorted:
```
conn_0_stmt_0_rows.csv
conn_0_stmt_1_rows.csv  <- Wrong position! Should be 3rd, not 2nd
conn_1_stmt_0_rows.csv
conn_1_stmt_1_rows.csv
```

## Solutions:

**A) Don't care** - file order doesn't need to match commands.yml order
- Pro: Simpler
- Con: Browsing directory is less intuitive

**B) Add global sequence prefix**: `0_conn_0_stmt_0_rows.csv`, `1_conn_1_stmt_0_rows.csv`, `2_conn_0_stmt_1_rows.csv`
- Pro: Sort order matches temporal order
- Pro: Still self-documenting
- Con: Longer filenames
- Con: Most verbose option

**C) Go back to flat numbering**: `rows_0.csv`, `rows_1.csv`
- Pro: Simple, matches order
- Con: Loses self-documenting property you wanted

Since you specifically wanted self-documenting names for human reviewers, I'd lean toward **option B** (global sequence prefix). The verbosity is worth it for clarity.

Thoughts?

User: let's consider a naming scheme like:

commands.yml
a_01_rows.csv
a_01_columns.csv
a_02_rows.csv
a_02_columns.csv
b_01_rows.csv
b_01_columns.csv

GitHub Copilot: Interesting! This is much cleaner:

- Connection IDs: `a`, `b`, `c` (instead of `conn_0`, `conn_1`)
- Statement IDs: `01`, `02`, `03` (zero-padded numbers instead of `stmt_0`)
- Multiple file types: `_rows.csv`, `_columns.csv`

## Observations:

**Pros:**
- ✅ Much shorter/cleaner: `a_01_rows.csv` vs `conn_0_stmt_0_rows.csv`
- ✅ Still self-documenting
- ✅ Zero-padding ensures proper sort within each connection (a_01, a_02, ... a_10, a_11)

**Sort order issue still exists:**
With interleaving, alphabetical order is still by connection then statement:
```
a_01_rows.csv
a_02_rows.csv
b_01_rows.csv  <- might have happened before a_02 in reality
b_02_rows.csv
```

This groups by connection rather than temporal order. Is that okay?

**Question about columns:**
Are you proposing storing column metadata in separate files (`a_01_columns.csv`) instead of inline in commands.yml? Currently it's:

```yaml
- method: columns
  result:
    - name: ID
      type: 4
```

Should that become a file reference instead?

User: I'm giving up on the filenames matching the temporal ordering.
I'm proposing storing columns in its own file. so .columns and .fetch* will be special in where they store their result.

also I meant to call it a_01_columns.yml, not csv

GitHub Copilot: Got it. So the scheme becomes:

## File Structure:

```
cassettes/
  <cassette_name>/
    commands.yml
    a_01_columns.yml
    a_01_rows.csv
    a_02_columns.yml
    a_02_rows.csv
    b_01_columns.yml
    b_01_rows.csv
    ...
```

## commands.yml:

```yaml
- method: connect
  connection_id: a
  dsn: server_a
  result:
    server: db.example.com
    database: PROD_DB
    user_hash: a1b2c3d4...

- method: connect
  connection_id: b
  dsn: server_b
  result:
    server: db2.example.com
    database: PROD_DB2
    user_hash: a1b2c3d4...

- method: run
  connection_id: a
  sql: "SELECT * FROM table1"
  params: []
  statement_id: "01"

- method: columns
  connection_id: a
  statement_id: "01"
  columns_file: a_01_columns.yml

- method: fetch_all
  connection_id: a
  statement_id: "01"
  rows_file: a_01_rows.csv
```

## a_01_columns.yml:

```yaml
- name: ID
  type: 4
  length: 10
- name: NAME
  type: 1
  length: 50
```

## a_01_rows.csv:

```csv
1,Alice
2,Bob
```

**Questions:**

1. **Connection ID scheme**: Single letters `a`, `b`, `c`... What after `z`? Go to `aa`, `ab`? Or switch to `a0`, `a1`?

2. **Methods with file references**: Only `columns` and `fetch*` methods store to files? Everything else (like `drop` with `result: null`) stays inline?

3. **Statement ID format**: Zero-padded to how many digits? `01`-`99`, or `001`-`999`?

User: 1. go to aa, ab, etc.
2. null result can happen for rows. we already handle it by creating a blank csv file. I'm fine with storing it in a way that captures the distinction between [] and nil if it doesn't add much complexity, but it seems tangential right now.
3. actually let's just lose the leading zero, there probably won't be more than a few statements per connection, and file sorting being clumsy isn't a big deal.

GitHub Copilot: Perfect. So the final scheme:

## File Structure:

```
cassettes/
  <cassette_name>/
    commands.yml
    a_1_columns.yml
    a_1_rows.csv
    a_2_columns.yml
    a_2_rows.csv
    b_1_columns.yml
    b_1_rows.csv
    ...
```

## commands.yml:

```yaml
- method: connect
  connection_id: a
  dsn: server_a
  result:
    server: db.example.com
    database: PROD_DB
    user_hash: a1b2c3d4...

- method: connect
  connection_id: b
  dsn: server_b
  result:
    server: db2.example.com
    database: PROD_DB2
    user_hash: a1b2c3d4...

- method: run
  connection_id: a
  sql: "SELECT * FROM table1"
  params: []
  statement_id: "1"

- method: columns
  connection_id: a
  statement_id: "1"
  columns_file: a_1_columns.yml

- method: fetch_all
  connection_id: a
  statement_id: "1"
  rows_file: a_1_rows.csv

- method: drop
  connection_id: a
  statement_id: "1"
  result: null
```

## Summary of decisions:

✅ Single `commands.yml` with all connections (preserves temporal order)  
✅ `connection_id` field on all commands  
✅ Connection IDs: `a`, `b`, ..., `z`, `aa`, `ab`, ...  
✅ Statement IDs: `1`, `2`, `3`, ... (no leading zeros)  
✅ Files: `{conn}_{stmt}_rows.csv` and `{conn}_{stmt}_columns.yml`  
✅ No `connection.yml` - metadata in `connect` commands  
✅ File sort order doesn't match temporal order (acceptable)  

Ready to write the ADR?

User: statement ids don't need to be strings if we lose the leading zero

GitHub Copilot: Right! Statement IDs can be integers:

```yaml
- method: run
  connection_id: a
  sql: "SELECT * FROM table1"
  params: []
  statement_id: 1

- method: columns
  connection_id: a
  statement_id: 1
  columns_file: a_1_columns.yml
```

Connection IDs stay as strings (`a`, `b`, `aa`) since they're letters.

Ready to write the ADR now?

User: since we're already talking about it -- fetch commands can return null. in that case the fetch entry won't have a filename key. playback should work correctly with either version, if that makes sense

GitHub Copilot: Yes, that makes sense:

**When fetch returns data:**
```yaml
- method: fetch_all
  connection_id: a
  statement_id: 1
  rows_file: a_1_rows.csv
```

**When fetch returns null:**
```yaml
- method: fetch
  connection_id: a
  statement_id: 1
  result: null
```

No file created, no `rows_file` key. Playback checks: if `rows_file` exists, load from file; if `result: null`, return null.

This applies to all fetch variants (`fetch`, `fetch_all`, `fetch_many`, `each_hash`).

Good clarification. Ready for the ADR now?

User: yes. keep the "justification" parts brief and not salesy

GitHub Copilot: Created [](file:///Users/john/Developer/Super8/super8/design/decision_records/adr_005_multiple_connections_per_cassette.md)

Created adr_005_multiple_connections_per_cassette.md. The ADR documents the complete design with examples and is ready for implementation.

Made changes.

User: let's modify the scheme a little -- instead of e.g. "...rows.csv" call it by the method name, "...fetch_all.csv" .

I'm not even sure what to do about methods like each_hash. just remove the reference for now.

GitHub Copilot: Read [](file:///Users/john/Developer/Super8/super8/design/decision_records/adr_005_multiple_connections_per_cassette.md)

Using "Multi-Replace String in Files"


```

```
Updated the file naming scheme to use method names (`a_1_fetch_all.csv` instead of `a_1_rows.csv`) and removed `each_hash` references as requested.

Made changes.

User: can you expand on "Sequential playback within each connection (same as current)"

(not in the document, in the chat, I'm confused about why that is if we're storing all commands in order)

GitHub Copilot: You're right to be confused - that statement is misleading given our design.

## What we actually have:

**Global sequential playback** through the single `commands.yml` file, not per-connection.

During playback:
1. Call `cassette.next_command` to get the next command (regardless of which connection)
2. Validate it matches what the code is trying to do
3. Return the recorded result
4. Repeat

If commands interleave between connections, playback sees them interleaved:
```ruby
# Recording:
db1.run("SQL A")  # → stored as command 0, connection_id: a
db2.run("SQL B")  # → stored as command 1, connection_id: b
db1.run("SQL C")  # → stored as command 2, connection_id: a

# Playback must happen in the same order:
db1.run("SQL A")  # ✅ matches command 0
db2.run("SQL B")  # ✅ matches command 1
db1.run("SQL C")  # ✅ matches command 2

# If order changes:
db1.run("SQL A")  # ✅ matches command 0
db1.run("SQL C")  # ❌ error - expected command 1 (connection b), got connection a
```

## The actual limitation:

**Order-dependent playback** - tests must execute commands in the exact same sequence as recording. This is the same as the current single-connection design, just now it applies across all connections.

I should probably just remove that limitation line since it's not really a new limitation compared to the current design. Want me to update it?

User: arguably, it's a feature, because the order that commands can be excuted matters, because commands might change database state

I don't think we can do both -- either we need to be strict about command order, or we do a more vcr-style "look it up if you have it and store it if you don't", which I don't think we can do because I think our commands are more likely to be stateful on the db side, or odbc driver side, etc. 

i'm not 100% sure but that's my thinking. you might want to add it as a note rather than a limitation, but keep it brief.

GitHub Copilot: Using "Replace String in File"


```

```
Updated to clarify that strict ordering is a design choice due to ODBC's stateful nature, not just a limitation carried over from the previous design.

Made changes.

User: it's not even that it's unlike HTTP requests (you can delete records using a REST API, for instance), but I think vcr can get away with it because that's typically not what people are testing

GitHub Copilot: Using "Replace String in File"


```

```
Updated to be more precise about why VCR-style matching doesn't fit ODBC's use case.

Made changes.