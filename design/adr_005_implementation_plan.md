# ADR 005 Implementation Plan: Multiple Connections Per Cassette

## Overview

This document outlines the concrete implementation steps needed to support multiple connections per cassette as specified in ADR 005.

## Core Changes Required

### 1. Connection ID Generator

**New functionality needed:**
- Create a connection ID generator that produces sequential letter-based IDs: `a`, `b`, `c`, ..., `z`, `aa`, `ab`, ...
- This should be a method in the `Cassette` class

**Implementation:**
```ruby
# In Cassette class
def next_connection_id
  # Convert @connection_counter (0, 1, 2...) to 'a', 'b', 'c'...'z', 'aa', 'ab'...
end
```

### 2. Cassette Class Changes

**Current state:**
- Tracks single DSN via `@dsn` attribute
- Saves `connection.yml` with DSN
- Uses simple counter for row files: `rows_0.csv`, `rows_1.csv`, etc.
- Doesn't track connection IDs

**Changes needed:**

1. **Add connection tracking:**
   - Add `@connection_counter` initialized to 0
   - Add `@connections` hash to store connection metadata by ID
   - Remove `@dsn` attribute (no longer needed)

2. **Update recording methods:**
   - `record()` method should always include `connection_id` in context
   - Add `record_connect()` method that:
     - Assigns next connection ID
     - Stores connection metadata (minimally the DSN)
     - Records connect command with connection_id and result metadata

3. **Update file naming:**
   - Change from `rows_N.csv` pattern to `{connection_id}_{statement_id}_{method}.csv`
   - Update `process_row_data!()` to use new naming scheme
   - Add support for `columns_file` references (not just `rows_file`)

4. **Remove connection.yml:**
   - Delete `save_connection_file()` method
   - Delete `load_connection()` method
   - Connection data now comes from `connect` commands in `commands.yml`

### 3. RecordingDatabaseWrapper Changes

**Current state:**
- Tracks statement IDs as `stmt_0`, `stmt_1`, etc.
- No connection ID tracking

**Changes needed:**

1. **Add connection_id parameter:**
   - Constructor should accept `connection_id` parameter
   - Store as `@connection_id` instance variable

2. **Update statement ID generation:**
   - Change from `stmt_0`, `stmt_1` to simple integers: `1`, `2`, `3`
   - Statement IDs are now per-connection (reset for each connection)

3. **Include connection_id in all recordings:**
   - Pass `connection_id` to all `cassette.record()` calls
   - Pass `connection_id` to `RecordingStatementWrapper`

### 4. RecordingStatementWrapper Changes

**Current state:**
- Records commands without connection context

**Changes needed:**

1. **Add connection_id parameter:**
   - Constructor should accept `connection_id` parameter
   - Store as `@connection_id` instance variable

2. **Include connection_id in all recordings:**
   - Pass `connection_id` to all `cassette.record()` calls

3. **Update file naming:**
   - When recording data that goes to files (columns, fetch_all, fetch_many)
   - Use pattern: `{connection_id}_{statement_id}_{method}.{ext}`
   - E.g., `a_1_columns.yml`, `a_1_fetch_all.csv`, `b_2_fetch_many.csv`

### 5. PlaybackDatabaseWrapper Changes

**Current state:**
- No connection ID awareness

**Changes needed:**

1. **Add connection_id parameter:**
   - Constructor should accept `connection_id` parameter
   - Store as `@connection_id` instance variable

2. **Include connection_id in validation:**
   - When validating commands, verify `connection_id` matches

3. **Pass connection_id to statement wrappers:**
   - Pass to `PlaybackStatementWrapper` constructor

### 6. PlaybackStatementWrapper Changes

**Current state:**
- Looks up files without connection context

**Changes needed:**

1. **Add connection_id parameter:**
   - Constructor should accept `connection_id` parameter
   - Store as `@connection_id` instance variable

2. **Update file lookups:**
   - When loading columns/rows files, use `{connection_id}_{statement_id}_{method}.{ext}` pattern

### 7. Super8 Module Changes (ODBC.connect interception)

**Current state:**
- Recording mode: Saves DSN to cassette directly
- Playback mode: Loads `connection.yml` and validates DSN
- Only supports one connection per cassette

**Changes needed:**

#### Recording Mode:
1. **Track multiple connections:**
   - Don't store DSN directly on cassette
   - Generate new connection ID for each `ODBC.connect` call
   - Record connect command with connection metadata (minimally the DSN)
   
2. **Pass connection_id to wrapper:**
   - Create `RecordingDatabaseWrapper` with `connection_id`

#### Playback Mode:
1. **Support multiple connections:**
   - Each `ODBC.connect` call gets next command from cassette
   - Validate it's a `connect` command
   - Validate DSN matches recorded DSN
   - Extract `connection_id` from command
   
2. **Pass connection_id to wrapper:**
   - Create `PlaybackDatabaseWrapper` with `connection_id`

3. **Remove connection.yml dependency:**
   - Don't call `cassette.load_connection()`
   - All data comes from commands.yml

## Implementation Order

Recommended order to minimize breaking changes:

1. **Phase 1: Foundation**
   - Add `next_connection_id()` to Cassette
   - Add connection tracking fields to Cassette
   - Add `connection_id` parameters to all wrapper classes (but don't use yet)

2. **Phase 2: Recording**
   - Update `Super8.setup_recording_mode()` to record connect commands
   - Update RecordingDatabaseWrapper to include connection_id in all records
   - Update RecordingStatementWrapper to include connection_id
   - Update file naming in cassette processing

3. **Phase 3: Playback**
   - Update `Super8.setup_playback_mode()` to handle connect commands
   - Update PlaybackDatabaseWrapper to validate connection_id
   - Update PlaybackStatementWrapper file lookups

4. **Phase 4: Cleanup**
   - Remove `connection.yml` support from Cassette
   - Remove `@dsn` attribute
   - Update tests

## Testing Strategy

1. **Test single connection first:**
   - Ensure existing single-connection tests still pass
   - Verify file naming works: `a_1_columns.yml`, `a_1_fetch_all.csv`

2. **Test multiple connections:**
   - Create test with 2 connections opening simultaneously
   - Verify connection IDs are `a` and `b`
   - Verify statement IDs are independent (both can have stmt 1)
   - Verify files use correct connection prefixes

3. **Test connection interleaving:**
   - Connection A opens
   - Connection B opens
   - Connection A executes query
   - Connection B executes query
   - Verify commands.yml shows correct temporal order

## Breaking Changes

All existing cassettes will need to be regenerated because:
- `connection.yml` is replaced by `connect` commands
- File naming changes from `rows_N.csv` to `{conn}_{stmt}_{method}.csv`
- `commands.yml` structure changes to include `connection_id`

## Implementation Notes

1. **Connection metadata:**
   - Record whatever connection info we receive (minimally the DSN)
   - Can only validate what we have available - don't try to extract additional metadata

2. **Username handling:**
   - Current code doesn't handle usernames - no need to add this now
   - Can be added later if needed

3. **Connection closing:**
   - Statement `close` already handled
   - Database `disconnect` should be handled if not already
   - Auto-closing via Ruby blocks can be ignored - not a practical concern since user would need to reconnect to do anything useful

## Migration Notes

For users upgrading from ADR 001 to ADR 005:
- Add note in CHANGELOG about breaking changes
