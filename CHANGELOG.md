# Changelog

## 0.2.0 (December 26, 2025)

* Added metadata.yml to cassettes (schema version 3).
  * Cassettes now include schema version, recording tool/version, and timestamp.
  * A script for migrating v2 cassettes is included as `scripts/migrate_cassettes_to_v3.rb`.
* Added CSV library to gemspec (stdlib csv is deprecated in Ruby 3.3 and being removed in 3.4).

## 0.1.0 (December 16, 2025)

* Changed cassette format to support storing multiple connections per cassette.
  * A script for migrating old cassettes is included as `scripts/migrate_cassettes_to_v2.rb`.

## 0.0.1 (December 16, 2025)

* Initial version
