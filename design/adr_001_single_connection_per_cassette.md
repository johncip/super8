# ADR 001: Single Connection Per Cassette

## Status

Accepted

## Context

Super8 needs to decide how to handle ODBC connections in cassettes. The options are:

1. **Separate `connection.yml`** — one connection per cassette, stored in a dedicated file
2. **Connection as command** — connections are entries in `commands.yml`, supporting multiple connections per cassette

## Scenarios Considered

1. **Single connection, multiple queries**
   - Description: One `ODBC.connect`, many queries
   - Frequency: Common

2. **Sequential reconnect (same DSN)**
   - Description: Retry logic reconnects to same server
   - Frequency: Rare

3. **Sequential connections (different DSNs)**
   - Description: Query server A, then server B based on results
   - Frequency: Possible

4. **Parallel connections**
   - Description: Two connections open simultaneously
   - Frequency: Rare

5. **Reconnect on failure**
   - Description: Connection drops, code reconnects
   - Frequency: Rare

## Analysis

**Supporting multiple connections requires:**
- Tracking `connection_id` on every command
- Mapping `ODBC::Database` object identity to connection IDs during record/playback
- More complex playback logic to route commands to correct fake connection

**Single connection approach:**
- Simpler implementation
- Matches our actual usage pattern (`ODBC.connect(dsn) { |db| ... }`)
- Clear upfront validation before replaying commands
- Limitation can be worked around with multiple cassettes if needed

## Decision

Support only a single connection per cassette.

**Rationale:** YAGNI. Our codebase uses single-connection blocks. The multi-connection scenarios are rare enough that requiring separate cassettes is acceptable. If a real need emerges, we can extend the format later.

## Consequences

- Users needing multiple DSNs in one test must use nested `use_cassette` calls or restructure tests
- Cassette format is simpler and more readable
- Implementation is straightforward
- Future extension to multiple connections is possible by migrating to connection-as-command format

## Future Enhancement

If multiple connections become necessary:
- Move connection info into `commands.yml` as `connect` commands
- Add `connection_id` field to all commands
- Track object identity mapping during record/playback

Example format with multiple connections:

```yaml
- index: 0
  method: connect
  dsn: server_a
  connection_id: conn_0

- index: 1
  method: connect
  dsn: server_b
  connection_id: conn_1

- index: 2
  method: run
  connection_id: conn_0
  sql: "SELECT * FROM users"
  statement_id: stmt_0

- index: 3
  method: run
  connection_id: conn_1
  sql: "SELECT * FROM orders"
  statement_id: stmt_1
```
