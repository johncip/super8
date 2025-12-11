# Super8 Cassette Schema

This document defines the file formats used in Super8 cassettes.

## Design Rationale: Command Log

ODBC is stateful and imperative, unlike HTTP's request/response model:
- `db.run(sql)` returns a Statement object, not data
- Data is fetched separately via `fetch`, `fetch_all`, etc.
- User might call `fetch()` N times on a large result set
- Statement options (e.g., `maxrows`) can affect what's returned

A simple request/response format doesn't work. Instead, cassettes are **command logs**:
a sequence of method calls and their results. Playback replays in order.

## Directory Structure

```
cassettes/
  <cassette_name>/
    connection.yml      # Connection scope metadata
    commands.yml        # Sequence of method calls and results
    rows_0.csv          # Row data for command 0 (if applicable)
    rows_1.csv          # Row data for command 1 (if applicable)
    ...
```

Row data is stored separately to keep `commands.yml` readable and diffable.

## connection.yml

Stores metadata about the ODBC connection used during recording.

```yaml
dsn: my_datasource
server: db.example.com
database: PROD_DB
user_hash: a1b2c3d4e5f6...
schema: APP_DATA
```

| Field | Source | Notes |
|-------|--------|-------|
| `dsn` | `SQL_DATA_SOURCE_NAME` (2) | The DSN passed to `ODBC.connect` |
| `server` | `SQL_SERVER_NAME` (13) | Physical host identifier |
| `database` | `SQL_DATABASE_NAME` (16) | Current database/catalog |
| `user_hash` | SHA256 of `SQL_USER_NAME` (47) | Hashed to avoid storing credentials in cassettes |
| `schema` | `SQL_ATTR_CURRENT_SCHEMA` (10004) | IBM extension; may be empty on other drivers. If empty, schema validation is skipped on playback. |

DBMS name and version are intentionally omitted — they can change server-side without affecting query behavior.

## commands.yml

Ordered sequence of intercepted method calls.

```yaml
- method: run
  sql: "SELECT ID, NAME FROM USERS WHERE STATUS = 'A'"
  params: []
  statement_id: stmt_0

- method: columns
  statement_id: stmt_0
  result:
    - name: ID
      type: 4
      length: 10
    - name: NAME
      type: 1
      length: 50

- method: fetch_all
  statement_id: stmt_0
  rows_file: rows_2.csv

- method: drop
  statement_id: stmt_0
  result: null
```

### Command Types

| Method | Fields | Notes |
|--------|--------|-------|
| `run` | `sql`, `params`, `statement_id` | Returns Statement; `statement_id` tracks which statement for later calls |
| `columns` | `statement_id`, `result` | Column metadata as array |
| `fetch_all` | `statement_id`, `rows_file` | Points to CSV file (array of arrays) |
| `fetch` | `statement_id`, `result` | Single row as array, or `null` at end |
| `fetch_hash` | `statement_id`, `result` | Single row as hash (YAML), or `null` at end |
| `fetch_many` | `statement_id`, `n`, `rows_file` | Points to CSV file (up to N rows) |
| `each_hash` | `statement_id`, `rows_file` | Points to YAML file (array of hashes) |
| `drop` | `statement_id`, `result` | Always `null` |

The `statement_id` field links fetch/columns/drop calls back to the `run` that created the statement.

Row data files use the format matching what ruby-odbc returns:
- Array data → `rows_N.csv`
- Hash data → `rows_N.yml`

## rows_N.csv

Row data stored as CSV. All values from ruby-odbc are strings, so no type conversion is needed.

```csv
"001","Alice"
"002","Bob"
```

- Field order matches column order from corresponding `columns` command
- Values preserve original padding/whitespace from the database
- Standard CSV quoting rules apply
- Filename includes command index for easy correlation

## Playback Behavior

1. Load `connection.yml`, validate DSN/database/schema match
2. Load `commands.yml` into ordered list
3. Intercept ODBC calls; for each call:
   - Pop next command from list
   - Verify method and args match
   - Return recorded result (loading from `rows_N.csv` if needed)
4. If call doesn't match next command, raise error with diff
5. If more calls than recorded commands, raise "no more interactions" error

## Future Considerations

- **Parameterized queries**: `params` field in `run` command; matching strategy TBD
- **Prepared statements**: `prepare` creates statement, `execute` binds params
- **`db.do`**: Returns row count (Integer), no statement created
