# ADR 004: Normalize Nil Fetch Results to Empty Arrays

## Status

Accepted

## Context

Ruby-ODBC's `fetch_all` method returns `nil` when a query produces no rows, but `[]` (empty array) when a query produces some rows that are then exhausted. This creates a semantic distinction between "no data ever" vs "data exists but consumed."

When recording these results to CSV files for Super8 cassettes:
- `nil` cannot be directly stored in a CSV file
- Reading an empty CSV file with `CSV.read()` returns `[]`, not `nil`
- This creates a mismatch between recorded and replayed values

The same issue affects other fetch methods (`fetch`, `fetch_hash`, `fetch_many`) that can return `nil` in various scenarios.

## Decision

**Normalize `nil` to `[]` (empty array) when recording row data to files.**

For all fetch methods that return row data:
- If the method returns `nil`, record it as `[]` in the data file
- Always create a data file, even if it's empty
- During playback, return the data from the file as-is (which will be `[]`)

This means:
- Original `nil` → Stored as `[]` → Replayed as `[]`
- Original `[]` → Stored as `[]` → Replayed as `[]`

## Alternatives Considered

### 1. No File Creation for Nil
- Don't create files when result is `nil`
- Store result inline in commands.yml as `result: null`
- **Rejected**: Breaks consistent "row data in separate files" pattern

### 2. Special Playback Logic  
- Create empty files for `nil` but track original return value
- Add special logic during playback to convert `[]` back to `nil` when needed
- **Rejected**: Adds complexity for minimal semantic benefit

### 3. YAML for Mixed Data Types
- Use YAML files instead of CSV to properly represent `nil`
- **Rejected**: Breaks cassette schema design and CSV human-readability

## Consequences

### Positive
- **Consistent file structure**: Every fetch call creates a predictable data file
- **Simple implementation**: No special cases or branching logic
- **Easy playback**: Just read file and return contents
- **Semantic equivalence**: For testing purposes, `nil` and `[]` both mean "no data"

### Negative
- **Lost semantic distinction**: Can't differentiate between "no rows" and "empty result"
- **Potential test mismatches**: Code that specifically checks for `nil` vs `[]` might behave differently

### Risk Mitigation
The distinction between `nil` and `[]` for "no data" scenarios is rarely significant in test contexts. Most application code treats both as falsy/empty conditions.

If specific test cases require exact `nil` behavior, they can be handled as edge cases or documented as known differences between record and playback modes.

## Implementation Notes

Applied to `fetch_all` initially in `Cassette#record_fetch_all`:

```ruby
def record_fetch_all(statement_id, result)
  # Normalize nil to empty array to match CSV playback behavior
  normalized_result = result || []
  record_rows_data(statement_id, "fetch_all", normalized_result, :csv)
end
```

This pattern should be applied consistently to other fetch methods (`fetch_many`, `each_hash`, etc.) when they are implemented.

## Date

December 11, 2025