# ADR 002: Avoid Gathering Extra Connection Details

## Status

Super 8 will not use `get_info()` or SQL queries to gather extra connection metadata beyond what's passed to `ODBC.connect()`.

## Context

During investigation of Super 8's connection handling, we discovered that ODBC provides a `get_info()` method that can retrieve rich connection metadata such as:

- Server name (`SQL_SERVER_NAME`)
- Database name (`SQL_DATABASE_NAME`) 
- Username (`SQL_USER_NAME`)
- Schema (`SQL_ATTR_CURRENT_SCHEMA`)
- DBMS version (`SQL_DBMS_VER`)
- Driver details (`SQL_DRIVER_NAME`)

This metadata could theoretically be stored in cassettes to provide additional context about where the recording was made. However, it would only be useful during recording mode for validation, not during playback.

## Investigation Findings

During investigation of connection metadata options, we discovered:

1. **Ruby-ODBC API surface**: Ruby-ODBC primarily exposes the DSN (and optionally username/password) passed to `ODBC.connect()`. Other connection details aren't directly accessible from the connection object.

2. **ODBC get_info() capability**: The underlying ODBC layer provides `db.get_info(code)` which can retrieve rich metadata like server name, database name, username, DBMS version, etc.
   ```ruby
   ODBC.connect("retalix") do |db|
     server = db.get_info(ODBC::SQL_SERVER_NAME)    
     database = db.get_info(ODBC::SQL_DATABASE_NAME)  
     username = db.get_info(ODBC::SQL_USER_NAME)
   end
   ```

3. **Alternative metadata sources**: We also investigated using SQL queries (both standard SQL and vendor-specific) to retrieve connection metadata. For example, getting the current schema/library required IBM-specific SQL queries rather than standard ODBC calls.

3. **get_info() behavior**: Upon further consideration, `get_info()` makes actual server requests - it's not just reading cached connection state. The same applies to SQL-based metadata queries.

## Problem

**Super 8 should work strictly with what it can glean from ruby-odbc's API surface.**

Using `get_info()` would violate this principle because:

1. **Limited connection API**: Ruby-ODBC only exposes what's passed to `ODBC.connect()` - either just the DSN, or DSN plus explicit credentials
2. **Server requests**: `get_info()` and SQL-based metadata queries make additional server calls beyond what the code under test is making
3. **Transparency**: A VCR-like library should be invisible and not initiate its own server communication

If Super 8 automatically used `get_info()` during recording, it would:
- Send requests the application code never intended to make
- Potentially change timing or trigger unexpected server-side behavior
- Violate the expectation that the library only intercepts existing calls

## Decision

**For MVP, Super 8 will record whatever connection arguments are passed to `ODBC.connect()`, without using `get_info()` to gather additional metadata.**

Connection scope validation will be limited to matching the arguments passed to `ODBC.connect()`:
- Simple and predictable
- No extra server calls
- Matches the ruby-odbc API surface that applications actually use
- Sufficient for most use cases

## Consequences

### Positive
- Super 8 remains side-effect free
- No unexpected server requests during recording
- Simpler implementation
- Aligns with ruby-odbc's design

### Negative  
- Cassettes contain less context about where they were recorded
- Cannot prevent scenarios where same DSN is reused across different environments during recording
- Users who want environment validation must implement it themselves

### Future Considerations

If richer connection metadata is needed in the future, it could be added as an opt-in feature:
- **Explicit opt-in** via configuration setting
- **Clearly documented** that it makes additional server calls during recording
- **Purely informational** - metadata would be stored in cassettes but not validated during playback

Example future API:
```ruby
Super8.configure do |config|
  config.gather_connection_metadata = true  # explicit opt-in, default false
end
```

Alternatively, users could add `get_info()` calls directly to their own code if they want connection metadata recorded in cassettes:

```ruby
ODBC.connect("retalix") do |db|
  # User adds these explicitly if they want metadata recorded
  server = db.get_info(ODBC::SQL_SERVER_NAME)    
  database = db.get_info(ODBC::SQL_DATABASE_NAME)
  
  # Their actual application logic
  results = db.run("SELECT * FROM customers")
end
```

## References

- Investigation findings in `lib/super8/design/investigations.md`
- Investigation script: `lib/super8/scripts/investigate_ruby_odbc.rb`
- Related chat logs: `lib/super8/design/copilot_chat_logs/13-one-connection-per-cassette.md`