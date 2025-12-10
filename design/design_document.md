# Super 8 Design Document

## Overview

A VCR-like library for ruby-odbc that records and replays database queries and responses for testing purposes. Similar to how VCR records HTTP interactions, Super 8 will record ODBC database queries and their results, allowing tests to run without an actual database connection while ensuring that changes to query structure are detected.

## Goals

- **Record Mode**: Capture real ODBC queries and responses to disk
- **Playback Mode**: Stub ODBC calls to return recorded responses
- **Query Validation**: Ensure recorded queries match current test queries (fail if queries change)
- **Deterministic Tests**: Run tests without database connectivity
- **Fast Tests**: Eliminate database round-trip time
- **Accurate Tests**: Use real database responses, not hand-crafted mocks

## Design Decisions

### 1. Naming & Location
- **Name**: Super 8 (code: `super8`, module: `Super8`)
- **Location**: `lib/super8/` (spike within app, extract to gem later if successful)
- **Cassette Storage**: Configurable via `Super8.configuration.cassette_directory`
  - Default: `spec/super8_cassettes`

### 2. API Design (MVP)
**Block-based API** for initial implementation:
```ruby
Super8.use_cassette("customer_query") do
  # ODBC calls here are recorded/replayed
end
```

**Manual activation** as alternative:
```ruby
Super8.insert_cassette("customer_query")
# ODBC calls
Super8.eject_cassette
```

**Not in MVP**: RSpec metadata integration (future enhancement)

**Important**: Core functionality must work without RSpec dependency.

### 3. File Format & Storage

**Multi-file approach** per cassette, stored in cassette directory.

> **Note**: The structure below is a preliminary sketch and may change as we learn more
> about ruby-odbc's behavior (e.g., how stateful operations like incremental fetching
> should be recorded).

```
spec/super8_cassettes/
  customer_query/
    connection.yml         # Connection metadata (DSN, redacted credentials)
    request_1.yml          # Query metadata (timestamp, etc.)
    query_1.txt            # Raw SQL query text
    columns_1.yml          # Column metadata (names, types if available)
    response_1.marshal     # Marshaled response data
    request_2.yml          # Second query in same cassette
    query_2.txt
    columns_2.yml
    response_2.marshal
```

**Rationale**:
- Separate query file allows easy inspection and diffs
- Marshal preserves Ruby object types (integers, dates, etc.) without data loss
- Column metadata separate for readability
- Multiple files per cassette supports sequential queries
- Text files (yml/txt) for human-readable parts
- Connection info stored separately (since it's per-cassette, not per-query)

**Connection Scope Recording** (Critical for Test Accuracy):
Unlike HTTP where each request can be independent, ODBC uses persistent connections:
- Connection establishes the **scope** of all subsequent queries:
  - Which server/host
  - Which database/catalog
  - Which schema/library (if applicable)
  - DSN name (which may encode all of the above)
- **Why we must record connection scope**:
  - Prevents false negatives: If test code has a bug and queries wrong database, test should fail
  - Without scope validation, Super 8 would return cached results for any query text match
  - Example failure: Code changes to query `PRODDB` instead of `TESTDB`, test passes with cached `TESTDB` results
- **What to record**:
  - DSN name (always available from connect args)
  - Additional metadata (database, schema, server) available via `get_info` but requires
    extra server calls; use only if explicitly enabled
  - Decision: Start with DSN only
- **What NOT to record**:
  - Username/password (security risk, and either not available or should be redacted)
- In playback mode, connection scope must match or raise error

**Storage Format**:
- All values from ruby-odbc are strings; CSV is sufficient for row data
- Column metadata is simple structured data; YAML is sufficient
- See `investigations.md` for details

### 4. Configuration

Global configuration object:
```ruby
Super8.configure do |config|
  config.cassette_directory = "spec/super8_cassettes"
  config.record_mode = :once  # :once, :new_episodes, :all, :none
  config.filter_sensitive_data = []  # Patterns to redact (usernames, passwords)
  config.default_cassette_options = {}
end
```

**Sensitive Data Filtering**:
- Automatically redact usernames and passwords from connection info
- Store as placeholders like `<USERNAME>`, `<PASSWORD>`
- In playback mode, these fields are ignored (fake connection anyway)
- May need DSN name for matching purposes, but credentials should be redacted

### 5. Query Matching (To Be Determined)
- Start with exact string match
- Consider normalization later if needed (whitespace, case)
- Configurable per-cassette if needed

### 6. Multiple Queries per Cassette
- Sequential matching (query order matters)
- Numbered files indicate sequence: `query_1.txt`, `query_2.txt`, etc.

### 7. Monkey Patching Strategy

**Available methods (may need interception)**:

Connection:
- `ODBC.connect(dsn, user?, password?)` - Returns `ODBC::Database`

Direct execution:
- `ODBC::Database#run(sql, *args)` - Execute query, returns `ODBC::Statement` or nil
- `ODBC::Database#do(sql, *args)` - Execute, return row count, auto-drop

Prepared statements:
- `ODBC::Database#prepare(sql)` - Returns `ODBC::Statement` without executing
- `ODBC::Statement#execute(*args)` - Bind parameters and execute

Result retrieval:
- `ODBC::Statement#fetch_all` - Get all rows
- `ODBC::Statement#columns` - Column metadata
- `ODBC::Statement#nparams` - Number of parameters
- `ODBC::Statement#parameters` - Parameter metadata

Cleanup:
- `ODBC::Statement#drop` / `#close`

**Patch scope**: Only active within `use_cassette` blocks or between `insert_cassette`/`eject_cassette`

**Connection Lifecycle**:
- `ODBC.connect(dsn, user, password)` or `ODBC.connect(dsn)` - record connection info
- Connection persists for duration of block or until closed
- In playback mode, no real connection is made
- Fake database object must respond to same methods as real one

## Architecture

> **Note**: The component breakdown below is a tentative sketch. Actual implementation
> may differ as we learn more.

### Core Components

1. **Super8 Module** (`lib/super8.rb`)
   - Main entry point
   - Configuration management
   - `use_cassette`, `insert_cassette`, `eject_cassette` methods
   - Cassette stack management (for nested cassettes)

2. **Super8::Configuration** (`lib/super8/configuration.rb`)
   - `cassette_directory` setting
   - `record_mode` setting
   - Default cassette options

3. **Super8::Cassette** (`lib/super8/cassette.rb`)
   - Load/save cassette files from directory
   - Store connection scope (DSN, database, schema, etc.)
   - Store interactions (query/response pairs)
   - Match incoming queries to recorded queries
   - Validate connection scope matches in playback mode
   - Handle multiple interactions per cassette
   - File naming: `connection.yml`, `request_N.yml`, `query_N.txt`, `columns_N.yml`, `response_N.marshal`

4. **Super8::Interaction** (`lib/super8/interaction.rb`)
   - Represents one query/response pair
   - Contains Request and Response objects
   - Handles serialization/deserialization of both sides

5. **Super8::Request** (`lib/super8/request.rb`)
   - Capture query details (SQL, DSN, metadata)
   - Query comparison/matching logic
   - Serialize to YAML + text file

6. **Super8::Response** (`lib/super8/response.rb`)
   - Capture ODBC results (columns, rows)
   - Preserve data types via Marshal
   - Serialize columns separately for readability

7. **Super8::ODBCInterceptor** (`lib/super8/odbc_interceptor.rb`)
   - Monkey patch ODBC module and classes
   - Enable/disable patches
   - Delegate to record or playback logic
   - Return fake connection/database objects in playback mode
   - Intercept `ODBC.connect` to record connection info

8. **Super8::Connection** (`lib/super8/connection.rb`)
   - Represents connection scope (DSN, database, schema, server)
   - Query connection for scope information after connecting
   - Redact any sensitive information (username/password) before serialization
   - Serialize to `connection.yml`
   - In playback mode: validate scope matches or raise error

9. **Super8::Errors** (`lib/super8/errors.rb`)
   - `QueryMismatchError` - query doesn't match recording
   - `CassetteNotFoundError` - cassette file missing in playback mode
   - `NoMoreInteractionsError` - more queries than recorded
   - `ConnectionMismatchError` - connection DSN doesn't match recording

### Workflow

#### Record Mode
1. Test starts, cassette is inserted
2. ODBC methods are patched
3. When `ODBC.connect` is called:
   - Allow real connection to proceed
   - Query connection for scope information (DSN, database, schema, server)
   - Record connection scope (redact any credentials if passed)
   - Wrap returned database object to intercept further calls
4. When queries are executed:
   - Allow real query execution
   - Capture query details (Request)
   - Capture response details (Response)
   - Store interaction in cassette
5. Cassette is ejected, save to disk:
   - Connection metadata (DSN, redacted credentials)
   - For each query: SQL text, column metadata, row data

#### Playback Mode
1. Test starts, cassette is loaded from disk (including connection info)
2. ODBC methods are patched
3. When `ODBC.connect` is called:
   - Load recorded connection scope from cassette
   - Verify connection scope matches (DSN, database, schema, etc.)
   - If mismatch: raise `ConnectionMismatchError` with details
   - Return a fake database object (no real connection made)
4. When queries are executed on fake database:
   - Match query against recorded queries in cassette
   - If match found: return recorded response
   - If no match: raise `QueryMismatchError` with details
5. Cassette is ejected (no save needed)

## Error Handling

- **No cassette file**: In `:once` mode, record new cassette
- **Query mismatch**: Provide detailed error message showing expected vs actual query
- **Multiple matches**: Use first match (or raise error if ambiguous)
- **Encoding issues**: Handle EBCDIC/IBM437 encoding like the current code

## Testing Strategy

- Test the library itself with RSpec
- Integration tests with actual ruby-odbc
- Unit tests with mocked ODBC objects
- Test different record modes
- Test error conditions

## Integration with Existing Code

### Current ODBC Usage Pattern
```ruby
ODBC.connect("retalix") do |db|
  statement = db.run(query)
  column_names = statement.columns.keys
  records = statement.fetch_all
  statement.drop
end
```

### With Super8
```ruby
Super8.use_cassette("retalix_customers") do
  ODBC.connect("retalix") do |db|
    statement = db.run(query)
    column_names = statement.columns.keys
    records = statement.fetch_all
    statement.drop
  end
end
```

Test code remains unchanged except for wrapping with `use_cassette`.

## Open Questions

1. Should we track statement options (e.g., cursor type)?
2. How to handle transactions (BEGIN, COMMIT, ROLLBACK)?
3. How to handle database errors in recordings?
4. How to handle concurrent test execution? (probably not needed for spike)
5. Should we support multiple DSNs in one cassette?
6. How to handle schema changes between recording and playback?
7. Query normalization — is exact match sufficient?

## References

- [VCR Documentation](https://github.com/vcr/vcr)
- [Stale Fish](https://github.com/jsmestad/stale_fish)
- [ruby-odbc Documentation](http://www.ch-werner.de/rubyodbc/)
- [ruby-odbc GitHub](https://github.com/larskanis/ruby-odbc)
