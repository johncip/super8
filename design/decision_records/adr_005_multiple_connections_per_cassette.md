# ADR 005: Multiple Connections Per Cassette

## Status

Accepted

Supersedes ADR 001.

## Context

The original design supported only a single connection per cassette. This is insufficient for testing code that opens multiple ODBC connections (e.g., a sync service that treats each table as a separate session).

Requirements:
- Support multiple connections in one cassette
- Preserve temporal ordering of commands across connections (don't lose information about interleaving)
- Maintain readability and diffability of cassettes
- Keep simple sequential playback model

## Decision

### Connection Tracking

- `ODBC.connect` is a regular command, not special-cased
- Each connection gets a unique `connection_id` assigned sequentially: `a`, `b`, ..., `z`, `aa`, `ab`, ...
- All commands include `connection_id` field (except `connect`, which establishes the ID)
- `connect` commands store connection metadata previously in `connection.yml`

### File Structure

Single `commands.yml` contains all commands from all connections in temporal order:

```
cassettes/
  <cassette_name>/
    commands.yml
    a_1_columns.yml
    a_1_fetch_all.csv
    a_2_fetch_all.csv
    b_1_columns.yml
    b_1_fetch_all.csv
```

### Connection IDs

- Sequential letter-based: `a`, `b`, `c`, ..., `z`, `aa`, `ab`, `ac`, ...
- Shorter than `conn_0`, `conn_1`
- Still human-readable in filenames

### Statement IDs

- Integer per connection: `1`, `2`, `3`, ...
- Statement namespaces are per-connection (connection `a` can have statement `1`, connection `b` can also have statement `1`)
- No leading zeros (won't have enough statements per connection to matter)

### File Naming

Pattern: `{connection_id}_{statement_id}_{method}.{ext}`

Examples:
- `a_1_columns.yml` - column metadata for connection a, statement 1
- `a_1_fetch_all.csv` - fetch_all data for connection a, statement 1
- `b_2_fetch_many.csv` - fetch_many data for connection b, statement 2

Files are self-documenting but sort by connection, not temporal order. This is acceptable since `commands.yml` preserves temporal order and interleaving will likely be rare.

### Data Storage

Commands that return large or structured data store it in separate files:
- `columns` → `{conn}_{stmt}_columns.yml`
- `fetch_all` → `{conn}_{stmt}_fetch_all.csv`
- `fetch_many` → `{conn}_{stmt}_fetch_many.csv`
- `fetch` → inline in commands.yml (single row or null)

Commands that return null have `result: null` inline, no file created.

Small inline data (like `drop` returning null) stays in commands.yml.

## Example

```yaml
# commands.yml
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
  statement_id: 1

- method: run
  connection_id: b
  sql: "SELECT * FROM table2"
  params: []
  statement_id: 1

- method: columns
  connection_id: a
  statement_id: 1
  columns_file: a_1_columns.yml

- method: fetch_all
  connection_id: a
  statement_id: 1
  rows_file: a_1_fetch_all.csv

- method: fetch
  connection_id: b
  statement_id: 1
  result: null

- method: drop
  connection_id: a
  statement_id: 1
  result: null
```

## Consequences

### Changes Required

- Add `connection_id` field to all commands
- Modify cassette to track multiple connections
- Update wrappers to know their connection ID
- Change file naming from `rows_N.csv` to `{conn}_{stmt}_{method}.csv`
- Remove `connection.yml` - data moves to `connect` commands
- Add `columns_file` reference for `columns` commands

### Benefits

- Supports testing code with multiple connections
- Preserves command interleaving information
- Filenames remain self-documenting
- Format is extensible

### Breaking Changes

- Existing cassettes must be regenerated
- File naming scheme changes
- `connection.yml` eliminated

### Limitations

- Commands must execute in the same order during playback as during recording. VCR-style request matching wouldn't work because we are currently assuming that ODBC interactions are more likely to contain stateful command sequences
- File sort order doesn't match temporal order (acceptable tradeoff)
