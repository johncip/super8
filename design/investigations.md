# Super8 Investigation Log

Q&A format for tracking what we've learned about ruby-odbc behavior.

## Connection API

**Q: How does `ODBC.connect` work?**

A: ✅ Answered — Three forms:
- `ODBC.connect(dsn)` — credentials from system DSN config
- `ODBC.connect(dsn, user, password)` — explicit credentials
- `ODBC.connect(dsn) { |db| ... }` — block form, auto-disconnect

Returns `ODBC::Database`. Current app uses DSN-only form with block.

**Q: Can we access credentials passed to connect?**

A: ✅ Answered — Only if passed explicitly. In DSN-only mode, ruby-odbc passes NULL to
the C API and unixODBC reads credentials from `/etc/odbc.ini`. ruby-odbc never sees them.

For Super8: nothing to redact in DSN-only mode. If explicit credentials, redact before storing.

**Q: What connection scope metadata is available?**

A: ✅ Answered — `db.get_info(code)` can retrieve metadata:

| Code | Constant | Example Value |
|------|----------|---------------|
| 2 | `SQL_DATA_SOURCE_NAME` | "retalix" |
| 13 | `SQL_SERVER_NAME` | "FFPRDATL.FERRAROFOODS.NET" |
| 16 | `SQL_DATABASE_NAME` | "S2186FEW" |
| 47 | `SQL_USER_NAME` | "NAPCOMM" |
| 10004 | `SQL_ATTR_CURRENT_SCHEMA` | "" (empty for our driver) |
| 17 | `SQL_DBMS_NAME` | "DB2/400 SQL" |
| 18 | `SQL_DBMS_VER` | "07.04.0015" |
| 6 | `SQL_DRIVER_NAME` | "libcwbodbc.dylib" |

**However**: Calling `get_info` sends a request to the server. Super8 should avoid making
calls that the code under test wouldn't make. For MVP, we can just record the DSN argument
passed to `ODBC.connect`. Using `get_info` for richer scope validation is optional and
should be explicitly enabled by the user if desired.

## Response Data

**Q: Are values from `fetch_all` typed or all strings?**

A: ✅ Answered — All strings. ruby-odbc returns string values for all column types.
CSV storage is sufficient; Marshal not required for type preservation.

Example: `["  2", "    ROMABO", "ROMA PZ BOWLING GREEN    ", "098", "  1"]`

Note: Values preserve original padding/whitespace from the database.

**Q: Can data be marshaled/unmarshaled?**

A: ✅ Answered — Yes. Marshal round-trip works and preserves data exactly.
Not required (since all strings), but available if needed.

## Column Metadata

**Q: What does `statement.columns` return?**

A: ✅ Answered — Hash by default (keys = column names, values = `ODBC::Column` objects).
`columns(true)` returns Array of `ODBC::Column` objects.

**Q: What properties does `ODBC::Column` have?**

A: ✅ Answered — Full list from investigation:
- `name` — column name (String)
- `table` — source table (String, often empty)
- `type` — ODBC type code (Integer)
- `length` — column length (Integer)
- `precision` — numeric precision (Integer)
- `scale` — numeric scale (Integer)
- `nullable` — allows NULL (Boolean)
- `searchable` — can be used in WHERE (Boolean)
- `unsigned` — unsigned numeric (Boolean)
- `autoincrement` — auto-increment column (Boolean)

For cassette storage, we likely only need: `name`, `type`, `length`.

## Statement Lifecycle

**Q: What is the typical statement lifecycle?**

A: ✅ Answered — Five steps:
1. `db.run(query)` — executes and returns `ODBC::Statement` (or nil for non-SELECT)
2. `statement.columns` — get column info
3. `statement.fetch` / `fetch_all` / `fetch_hash` — retrieve data
4. `statement.drop` or `statement.close` — release resources
5. Statements should be dropped/closed for memory performance

**Q: Does any ruby-odbc method return data directly (without fetch)?**

A: ✅ Answered — No. All query methods (`run`, `do`, `prepare`+`execute`) return either
a Statement object or an Integer (row count). Data must be fetched separately.

This confirms the two-phase model: execute → fetch.

**Q: What fetch methods exist?**

A: ✅ Answered — Multiple options with different behaviors:
- `fetch` — single row, returns nil at end
- `fetch_all` — all remaining rows as Array of Arrays
- `fetch_hash` — single row as Hash
- `fetch_many(n)` — up to N rows
- `each` / `each_hash` — iterators

Users might call `fetch` multiple times instead of `fetch_all`. Cassette format
must handle this (command log, not simple request/response).

**Q: What methods are available on ODBC::Statement?**

A: ✅ Answered — Key methods from investigation:

Fetch methods: `fetch`, `fetch_all`, `fetch_hash`, `fetch_many`, `fetch_scroll`, `each`, `each_hash`

Metadata: `columns`, `ncols`, `nparams`, `nrows`, `parameters`, `parameter`

Execution: `execute`, `prepare`, `run`, `do`

Options: `maxrows`, `maxrows=`, `timeout`, `timeout=`, `cursortype`, `cursortype=`

Cleanup: `drop`, `close`, `cancel`

## Prepared Statements & Parameters

**Q: Can we observe the SQL template and parameters separately?**

A: ✅ Answered — Yes, at intercept time. `db.run(sql, *args)` receives them separately.

**Q: Can we retrieve SQL or bound values from a Statement after execution?**

A: ✅ Answered — No. Must capture at intercept time; cannot query the statement later.

**Q: How can we tell if a query used parameters?**

A: ✅ Answered — `stmt.nparams` returns the parameter count. 0 = literal SQL, N = parameterized.

**Q: Can we re-execute a prepared statement with different parameters?**

A: ✅ Answered — Yes. `stmt.execute(*new_args)` works. ruby-odbc maintains the template.

See: `lib/super8/scripts/investigate_prepared_statements.rb`

**Q: How does parameter binding work?**

A: ✅ Answered — Parameters are positional, bound by `?` placeholders in SQL.
- `db.prepare(sql)` returns Statement
- `stmt.execute(*args)` binds args to `?` placeholders and executes
- `stmt.nparams` returns parameter count
- `stmt.parameters` returns array of `ODBC::Parameter` objects
- `stmt.parameter(n)` returns info for n-th parameter
- `db.run(sql, *args)` is a convenience that prepares + executes in one call
- `db.do(sql, *args)` is like `run` but returns row count and auto-drops statement

## Credential Handling

**Q: How does ruby-odbc handle credentials under the hood?**

A: ✅ Answered — ruby-odbc calls the C API function `SQLConnect(dsn, user, password)`.

When user/password are nil (DSN-only case):
- ruby-odbc passes `suser = NULL` with `suser_length = 0`
- Same for password
- The ODBC driver manager (unixODBC) receives NULL credentials
- Driver manager reads credentials from DSN configuration in `/etc/odbc.ini`
- **ruby-odbc never sees the credentials in the DSN-only case**

For Super8:
- DSN-only mode: nothing to redact (ruby-odbc doesn't have access)
- Explicit credentials: must redact before storing, use `<REDACTED>` placeholder
- Playback mode: ignore credentials entirely (connection is faked)

## File Format

**Q: Is Marshal necessary for response data?**

A: ✅ Answered — No. All values are strings, so CSV is sufficient.
Marshal works but adds complexity for no benefit.

**Q: Is Marshal or YAML needed for column metadata?**

A: ✅ Answered — YAML is sufficient. Column metadata is simple structured data
(name, type, length). No complex Ruby objects to preserve.

**Q: Does round-trip serialization preserve data?**

A: ✅ Answered — Yes. Marshal round-trip tested and works.
CSV round-trip for string data is straightforward.

## Open Questions

**Q: Should we track statement options (e.g., `maxrows`, cursor type)?**

A: TBD. Options could affect what data is returned. May need to record and validate.

**Q: How to handle transactions?**

A: TBD. Out of scope for MVP (current app doesn't use them via ODBC).

**Q: How to handle database errors in recordings?**

A: TBD. If query fails during record, should we store the error? Probably yes, for accuracy.

**Q: How to handle schema changes between recording and playback?**

A: TBD. If columns change, playback will return stale data. Rely on test failures to catch this?

**Q: Query normalization — is exact match sufficient?**

A: TBD. Start with exact match. Consider whitespace/case normalization if needed later.

**Q: What happens if user refactors parameterized → literal SQL (or vice versa)?**

A: TBD. Options:
- Fail (strict: query structure changed)
- Warn (structure changed but semantically equivalent)
- Match (normalize both for comparison)

**Q: Error message design for query mismatches?**

A: TBD. Should show diff between expected and actual query. Details to be worked out.

**Q: How to handle missing cassettes in different record modes?**

A: TBD. Behavior depends on record mode (`:once` records, `:none` fails, etc.)

**Q: Thread safety for cassette stack?**

A: TBD. Probably not needed for spike (tests run sequentially).

## Scripts

- `lib/super8/scripts/investigate_ruby_odbc.rb` — data types, columns, connection scope
- `lib/super8/scripts/investigate_prepared_statements.rb` — parameterized queries, nparams
