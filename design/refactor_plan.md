# Super8 Refactoring Plan

## Current State Summary

- **Cassette** does too much: holds data, knows about file I/O, increments counters, writes commands.yml on every change
- **StatementWrapper** only handles record mode; playback will require a parallel implementation
- **use_cassette** has inline monkey-patching with closures over cassette — this couples orchestration tightly to patching logic
- `db.run` is special-cased in `use_cassette`; adding more database methods means more inline patching

## Problems to Solve

1. We need to stub more database methods than just `db.run` — can't treat it as a special case
2. Cassette does too many things, and it will get worse when playback is added
3. No easy, high-level way to describe the control flow
4. Nothing is "closed for modification" — adding playback touches everything

## Proposed Architecture

**Three layers:**

1. **Cassette (Data + Persistence)** — like an ActiveRecord model
2. **Wrappers (ODBC Adapters)** — record mode and playback mode wrappers for Database and Statement
3. **Director** — controls cassette lifecycle and installs/removes wrappers

**High-level description:** Cassettes are data that know how to store and load themselves. There are wrappers for ODBC library classes/objects. There is a director that controls communication between the wrappers and cassettes.

---

## 1. Cassette as a Data Object

**Goal:** Cassette holds data and knows how to persist itself. It does not coordinate recording.

```ruby
class Cassette
  attr_accessor :name, :dsn
  attr_reader :commands

  def initialize(name)
    @name = name
    @dsn = nil
    @commands = []
    @cursor = 0
  end

  # Generic recording — wrappers pass method name and context
  def record(method, **context)
    @commands << {method: method, **context}
  end

  # Generic playback — validates method/context match, returns stored result
  def playback(method, **context)
    cmd = @commands[@cursor]
    @cursor += 1
    validate!(cmd, method, context)
    cmd[:result]
  end

  # Persistence
  def save
    # writes connection.yml, commands.yml, and all rows_N files in one pass
  end

  def self.load(name)
    # class method, returns populated Cassette with commands and dsn
  end

  private

  def validate!(cmd, expected_method, expected_context)
    raise CommandMismatchError unless cmd[:method] == expected_method
    expected_context.each do |key, value|
      raise CommandMismatchError unless cmd[key] == value
    end
  end
end
```

### Simplifications from Non-Incremental Saving

- No `@rows_file_counter` — assign all file names at save time
- No `save_commands` called on every `record_*` — just append to `@commands`
- `save` writes connection.yml, commands.yml, and all rows_N files in one pass
- Easier to test: build up commands in memory, then verify the final structure

### Generic Interface Benefits

- Cassette doesn't know about specific ODBC methods — just stores/retrieves tuples
- Validation logic lives in one place (`playback`), not scattered across wrappers
- Wrappers are the only place that knows about the 30 ODBC methods
- Cursor advances automatically in `playback`; simple sequential model matches ODBC's stateful nature

---

## 2. Wrappers for ODBC Objects

**Goal:** Separate record-mode and playback-mode wrappers. Each implements the same interface as the real object.

### RecordingDatabaseWrapper

```ruby
class RecordingDatabaseWrapper
  def initialize(real_db, cassette)
    @real_db = real_db
    @cassette = cassette
    @statement_counter = 0
  end

  def run(sql, *params)
    statement_id = "stmt_#{@statement_counter}"
    @statement_counter += 1

    real_statement = @real_db.run(sql, *params)
    @cassette.record(:run, sql: sql, params: params, statement_id: statement_id)
    RecordingStatementWrapper.new(real_statement, statement_id, @cassette)
  end

  # Add more methods here: do, prepare, etc.
end
```

### PlaybackDatabaseWrapper

```ruby
class PlaybackDatabaseWrapper
  def initialize(cassette)
    @cassette = cassette
    @statement_counter = 0
  end

  def run(sql, *params)
    # Cassette validates sql/params match and returns stored statement_id
    @cassette.playback(:run, sql: sql, params: params)
    statement_id = "stmt_#{@statement_counter}"
    @statement_counter += 1
    PlaybackStatementWrapper.new(statement_id, @cassette)
  end

  # No validation here — cassette.playback handles it
end
```

### RecordingStatementWrapper

Current `StatementWrapper`, refactored to use `cassette.add_command`:

```ruby
class RecordingStatementWrapper
  def initialize(real_statement, statement_id, cassette)
    @real_statement = real_statement
    @statement_id = statement_id
    @cassette = cassette
  end

  def columns(as_ary = false)
    result = @real_statement.columns(as_ary)
    @cassette.record(:columns, statement_id: @statement_id, as_ary: as_ary, result: result)
    result
  end

  def fetch_all
    result = @real_statement.fetch_all || []
    @cassette.record(:fetch_all, statement_id: @statement_id, result: result)
    result
  end

  def drop
    result = @real_statement.drop
    @cassette.record(:drop, statement_id: @statement_id, result: nil)
    result
  end

  # cancel, close, etc.
end
```

### PlaybackStatementWrapper

```ruby
class PlaybackStatementWrapper
  def initialize(statement_id, cassette)
    @statement_id = statement_id
    @cassette = cassette
  end

  def columns(as_ary = false)
    @cassette.playback(:columns, statement_id: @statement_id, as_ary: as_ary)
  end

  def fetch_all
    @cassette.playback(:fetch_all, statement_id: @statement_id)
  end

  def drop
    @cassette.playback(:drop, statement_id: @statement_id)
    nil
  end
end
```

### Benefits

- Adding a new stubbed method (e.g., `Database#prepare`, `Database#do`) = add it to both wrapper pairs
- No special-casing in director; it just picks which wrapper class to use
- Closed for modification: playback doesn't touch recording wrappers

---

## 3. Director

**Goal:** Single place that controls the cassette lifecycle and installs wrappers.

```ruby
class Director
  def initialize
    @original_connect = nil
    @cassette = nil
    @mode = nil
  end

  def use_cassette(name, mode:)
    @mode = mode
    @cassette = mode == :record ? Cassette.new(name) : Cassette.load(name)
    install_connect_patch
    yield
  ensure
    remove_connect_patch
    @cassette.save if recording?
  end

  def recording?
    @mode == :record
  end

  def install_connect_patch
    @original_connect = ODBC.method(:connect)
    cassette = @cassette
    mode = @mode

    ODBC.define_singleton_method(:connect) do |dsn, &block|
      if mode == :record
        cassette.dsn = dsn
        @original_connect.call(dsn) do |real_db|
          wrapped_db = RecordingDatabaseWrapper.new(real_db, cassette)
          block&.call(wrapped_db)
        end
      else
        raise ConnectionMismatchError unless cassette.dsn == dsn
        fake_db = PlaybackDatabaseWrapper.new(cassette)
        block&.call(fake_db)
      end
    end
  end

  def remove_connect_patch
    ODBC.define_singleton_method(:connect, @original_connect) if @original_connect
  end
end
```

### Benefits

- Mode is explicit (`mode: :record` or `mode: :playback`)
- Wrappers don't know about mode switching
- Auto-detection can be added later as syntactic sugar

---

## 4. Handling Multiple Database Methods

Instead of special-casing `db.run` in the director, the DatabaseWrapper classes implement all needed methods:

| Method | RecordingDatabaseWrapper | PlaybackDatabaseWrapper |
|--------|--------------------------|-------------------------|
| `run(sql, *params)` | delegates + wraps result | validates + returns fake statement |
| `do(sql, *params)` | delegates + records | validates + returns recorded row count |
| `prepare(sql)` | delegates + wraps result | validates + returns fake statement |

The director doesn't grow when new methods are added — only the wrappers do.

---

## 5. File Structure After Refactoring

```
lib/super8/
  super8.rb                    # module entry point
  director.rb                  # cassette lifecycle + patching
  cassette.rb                  # data + persistence only
  config.rb                    # unchanged
  errors.rb                    # add CommandMismatchError, ConnectionMismatchError
  wrappers/
    recording_database_wrapper.rb
    recording_statement_wrapper.rb
    playback_database_wrapper.rb
    playback_statement_wrapper.rb
```

---

## Summary of Design Questions

| Question | Answer |
|----------|--------|
| **Non-incremental saving simplifications?** | Eliminates per-command file writes, row file counters, repeated YAML serialization. `save` becomes a single-pass operation at eject. Commands stay in memory as plain hashes. |
| **Make Cassette like ActiveRecord?** | Yes — Cassette holds data (`@commands`, `@dsn`), has `save` (instance) and `load` (class method). Recording/playback logic moves to wrappers. |
| **Cursor simplifications?** | `next_command` / `peek_command` make playback straightforward: the cassette always knows what's expected next. No searching, no tracking consumed commands externally. |
| **Closed for modification?** | Separate RecordingXWrapper and PlaybackXWrapper classes. Adding playback = adding new classes, not modifying existing ones. Director picks wrapper classes based on mode. |

---

## Migration Steps

1. **DONE: Add generic `record`/`playback` methods to Cassette** — validation moves into `playback`. Remove method-specific `record_*` methods.

2. **DONE: Implement deferred `save`** — one method that writes connection.yml, commands.yml, and rows files.

3. **DONE: Extract RecordingDatabaseWrapper** — move `db.run` interception out of `use_cassette`. Use `cassette.record`.

4. **DONE: Rename StatementWrapper → RecordingStatementWrapper** — have it use `cassette.record`.

5. **DEFERRED: Create PlaybackDatabaseWrapper and PlaybackStatementWrapper** — use `cassette.playback`. (Deferred until playback is needed)

6. **DEFERRED: Create Director class** — move `use_cassette` logic there. Accept explicit `mode:` parameter. (Deferred - wrappers currently call `cassette.record` directly, creating coupling that Director was meant to eliminate)

---

## Refactoring Status

**Completed:** Steps 1-4. The core refactoring objectives have been met:
- Cassette is now a simple data object with generic `record` method and deferred persistence
- Wrappers handle ODBC-specific concerns and call `cassette.record` with method name + context
- Code is structured to make adding playback easier when needed

**Deferred:** Steps 5-6. Director extraction and playback wrappers are not needed for current record-only use case.
