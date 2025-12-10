# Super8 Cassette Schema

This document defines the file formats used in Super8 cassettes.

## Directory Structure

```
cassettes/
  <cassette_name>/
    connection.yml
    query_0/
      query.sql
      columns.yml
      rows.csv
    query_1/
      ...
```

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

## query.sql

The raw SQL query text, stored as-is. Used for matching incoming queries during playback.

## columns.yml

Column metadata as an ordered array (order matches row field positions).

```yaml
- name: ID
  type: 4
  length: 10
- name: NAME
  type: 1
  length: 50
- name: CREATED_AT
  type: 11
  length: 26
```

| Field | Source | Notes |
|-------|--------|-------|
| `name` | `ODBC::Column#name` | Column name |
| `type` | `ODBC::Column#type` | ODBC type code |
| `length` | `ODBC::Column#length` | Column length |

Additional column metadata (nullable, precision, scale, etc.) is available from `ODBC::Column` but omitted for simplicity. Can be added later if needed.

## rows.csv

Row data stored as CSV. All values from ruby-odbc are strings, so no type conversion is needed.

```csv
"001","Alice","2024-01-15 09:30:00"
"002","Bob","2024-02-20 14:45:00"
```

- Field order matches `columns.yml` order
- Values preserve original padding/whitespace from the database
- Standard CSV quoting rules apply
