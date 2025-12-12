# Super8 API Support

Methods that Super8 needs to intercept, organized by priority.

## Cassette Format: Command Log

Unlike HTTP's request/response model, ODBC is stateful and imperative. A query execution
returns a Statement object; data must be fetched separately via `fetch`, `fetch_all`, etc.
Users might call `fetch()` three times on a 10,000 row result.

The cassette format is a **command log**: a sequence of `{call: [method, args], result: data}`
entries. Playback replays commands in order, returning recorded results.

This allows incremental support for different fetch methods while keeping architecture simple.

## MVP (Currently Used in Codebase)

These are the only ODBC methods currently used in `RetalixFetcher`:

| Method | Status | Notes |
|--------|--------|-------|
| `ODBC.connect(dsn)` | [x] DONE | Block form only; no credentials passed |
| `Database#run(sql)` | [x] DONE | No parameters used currently |
| `Statement#fetch_all` | [x] DONE | Returns Array of Arrays |
| `Statement#columns` | [x] DONE | Returns Hash of column metadata |
| `Statement#drop` | [x] DONE | Cleanup; returns statement object but we don't log it |

## Phase 2: Incremental Fetch Methods

Support different ways to retrieve data from a Statement:

| Method | Status | Notes |
|--------|--------|-------|
| `Statement#fetch` | [ ] TODO | Single row; returns nil at end |
| `Statement#fetch_first` | [ ] TODO | First row; rewinds cursor |
| `Statement#fetch_hash` | [ ] TODO | Row as Hash |
| `Statement#fetch_many(n)` | [ ] TODO | Up to N rows |
| `Statement#each` | [ ] TODO | Iterator; record yields sequence of rows |
| `Statement#each_hash` | [ ] TODO | Iterator returning hashes |
| `Statement#column(n)` | [ ] TODO | Metadata for nth column |

Recording strategy: record each call and its result. On playback, return recorded results
in order. If user changes code to call `fetch` 5 times instead of `fetch_all`, cassette
won't match—this is intentional (query behavior changed).

## Phase 3: Parameterized Queries

Support parameters even though not currently used—likely needed soon:

| Method | Status | Notes |
|--------|--------|-------|
| `Database#run(sql, *args)` | [ ] TODO | Template + params |
| `Database#do(sql, *args)` | [ ] TODO | Returns row count, auto-drops |
| `Database#prepare(sql)` | [ ] TODO | Returns Statement for later execute |
| `Statement#execute(*args)` | [ ] TODO | Bind params to prepared statement |

### Investigation Findings (from `investigate_prepared_statements.rb`)

- At intercept time: we receive SQL template and `*args` separately ✓
- `stmt.nparams` reliably indicates if params were used (0 = literal, N = parameterized)
- Cannot retrieve SQL or bound values from statement after the fact
- Must capture at intercept time, not query later
- ruby-odbc maintains template/params separately (re-execution works)

### Matching Strategy Decision

**Decision: Strict fail with descriptive diff.**

If user refactors `db.run("...?", val)` to `db.run("...'val'")`:
- Playback fails immediately
- Error message shows diff: expected SQL/params vs actual
- User must re-record the cassette

Rationale: Simpler to implement, safer (forces explicit re-recording), and the cassette
format already stores `sql` and `params` separately—enough info for a helpful error.

## Phase 4: Everything Else

| Method | Status | Notes |
|--------|--------|-------|
| `Statement#run(sql, *args)` | [ ] TODO | Re-prepare on existing statement |
| `Statement#prepare(sql)` | [ ] TODO | Re-prepare on existing statement |
| `Statement#cancel` | [x] DONE | Cancel running statement |
| `Statement#close` | [x] DONE | Close statement (softer than drop) |
| `Database#proc(sql) { }` | [ ] TODO | ODBCProc wrapper |
| `Database#newstmt` | [ ] TODO | Create blank statement |
| `ODBC.connect(dsn, user, pw)` | [ ] TODO | Credentials passed explicitly |

## Out of Scope

- Transactions (`commit`, `rollback`, `transaction`)
- Connection pooling options
- Cursor types and scrolling (`fetch_scroll`)
- Statement options (`maxrows`, `timeout`, etc.)
- Metadata queries (`tables`, `columns`, `indexes`, etc.)

---

## Status Key

- [ ] TODO - Not started
- [ ] WIP - In progress
- [x] DONE - Implemented and tested
- [ ] SKIP - Decided not to support
