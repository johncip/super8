# ADR 003: No Support for Concurrent Threads

## Status
Accepted

## Context
Super8 uses global method replacement (monkey patching) to intercept ODBC calls. Multiple threads sharing the same process would share this global state.

## Decision
Super8 will not support multiple concurrent threads within the same process.

## Consequences
- **Positive**: Simple implementation, no thread synchronization complexity
- **Negative**: Cannot run tests in parallel using thread-based parallelism
- **Mitigation**: 
  - Most parallel RSpec solutions (like `parallel_tests` gem) use process-based parallelism, which works fine since each process has isolated global state
  - Multiple simultaneous reads from existing cassettes are safe across processes
  - If this becomes a public gem, documentation should note that record mode spec runs should be done without parallelism to avoid race conditions when writing cassette files

## Alternative Thread-Safe Approach
A thread-safe version would require:
- Thread-local storage for method replacements instead of global monkey patching
- Mutex synchronization around cassette file I/O operations
- Per-thread cassette state management
- Significantly more complex implementation with potential performance overhead

This complexity is not justified for the current use case where process-based parallelism is sufficient.