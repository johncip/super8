# Super8 Implementation Plan

Living TODO list for building Super8.

## Phase 0: Investigation

- [x] Create script to inspect ruby-odbc data types and column metadata
- [x] Run script, confirm all values are strings (CSV sufficient)
- [x] Create script to investigate prepared statements and parameters
- [x] Confirm nparams indicates parameterization
- [x] Confirm SQL/params must be captured at intercept time (not queryable later)
- [x] Confirm two-phase model (execute → fetch) for all query methods
- [x] Document which methods to intercept (see api_support.md)
- [x] Design cassette format for command log style (see cassette_schema.md)
- [x] Decide matching strategy for parameterized vs literal SQL refactoring

## Phase 1: Record Mode (only record, no playback)

Record mode implementation - capture real ODBC calls and save to cassette.

- [x] `Super8.use_cassette(name) { }` block API
- [x] `Super8.configure { |c| c.cassette_directory = ... }`
- [x] Cassette class skeleton (name, save, load) with basic specs
- [x] Intercept `ODBC.connect(dsn)` (block form) - record connection info
- [x] Intercept `Database#run(sql)` (no params) - record query and result
- [x] Intercept `Statement#columns` - record column metadata
- [x] Intercept `Statement#fetch_all` - record row data
- [x] Intercept `Statement#drop` - record cleanup call
- [x] Intercept `Statement#cancel` - record statement cancellation
- [x] Intercept `Statement#close` - record statement closure

## Phase 2: Playback Mode

Playback mode implementation - return recorded data, validate matches.

- [x] Be able to load cassette / command log
- [x] Return fake database object
- [x] Replay recorded interactions in sequence
- [x] Connection scope validation (DSN match)
- [x] Query mismatch error
- [ ] Integration test without database connection

## Phase 3: Incremental Fetch

Support different ways to retrieve data from a Statement.

- [ ] Intercept `Statement#fetch` (single row)
- [ ] Intercept `Statement#fetch_hash`
- [ ] Intercept `Statement#fetch_many(n)`
- [ ] Intercept `Statement#each` / `Statement#each_hash`
- [ ] Command log format handles mixed fetch calls

## Phase 4: Parameterized Queries

- [ ] Intercept `Database#run(sql, *args)` with parameters
- [ ] Intercept `Database#do(sql, *args)`
- [ ] Intercept `Database#prepare(sql)` + `Statement#execute(*args)`
- [ ] Record template + params in cassette
- [ ] Decide and implement matching strategy for params

## Phase 5: Polish

- [ ] RSpec metadata integration (`super8: "cassette_name"`)
- [ ] Multiple record modes (`:once`, `:new_episodes`, `:all`, `:none`)
- [ ] Manual `insert_cassette` / `eject_cassette` API
- [ ] Better error messages
- [ ] Documentation
- [ ] Consider extracting as gem

## Out of Scope

- Transactions
- Connection pooling
- Cursor scrolling / `fetch_scroll`
- Statement options (`maxrows`, `timeout`)
- Metadata queries (`tables`, `columns`, `indexes`)
- Multiple DSNs per cassette
- Thread safety / concurrent test execution
