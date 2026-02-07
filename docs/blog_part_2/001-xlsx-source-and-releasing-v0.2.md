---
title: "Building DataPorter #18 -- XLSX Support & Releasing v0.2.0"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 18
tags: [ruby, rails, rails-engine, gem-development, xlsx, release, changelog]
published: false
---

# XLSX Support & Releasing v0.2.0

> Adding the most requested source format and shipping a proper release -- version bump, CHANGELOG, and all.

## Context

In [part 17](#), we wrapped up the first season of the series with a showcase of DataPorter v0.1.0. The gem shipped with CSV, JSON, and API sources, a complete 3-step workflow, and 221 specs.

This article opens season 2. We add XLSX support -- the most requested format -- and walk through the release process: version bump, CHANGELOG, and what changes when a gem goes from "first release" to "maintained project".

## The problem

Most users export data from Excel. They click "Save As", get an `.xlsx` file, and expect to upload it. Telling them to convert to CSV first is friction we can remove. XLSX is table-shaped data, just like CSV -- the engine should handle it natively.

## What we're building

By the end of this article, a user can drag an `.xlsx` file onto the dropzone and the engine parses it exactly like a CSV: first row as headers, remaining rows as data, with the same column mapping.

```ruby
# The source API stays consistent
source = DataPorter::Sources::Xlsx.new(data_import, file_path: "contacts.xlsx")
rows = source.fetch
# => [{ first_name: "Alice", last_name: "Smith", email: "alice@example.com" }, ...]
```

## Implementation

### Step 1 -- Choosing a gem

Two options for parsing `.xlsx` in Ruby:

| Gem | Approach | Memory | Features |
|-----|----------|--------|----------|
| **roo** | Loads entire file | High | Reads xls, xlsx, csv, ods |
| **creek** | Streaming SAX parser | Low | Read-only, xlsx only |

We chose **creek**. DataPorter only needs to read xlsx, and streaming aligns with future batch import support for large files. One dependency, one job, done.

```ruby
# data_porter.gemspec
spec.add_dependency "creek"
```

### Step 2 -- The Xlsx source class

The pattern is identical to `Sources::Csv`: inherit from `Base`, implement `fetch`, return an array of symbol-keyed hashes. One key difference: creek needs a file path, not string content. So we accept `file_path:` for testing and write to a `Tempfile` when downloading from ActiveStorage.

```ruby
# lib/data_porter/sources/xlsx.rb
class Xlsx < Base
  def initialize(data_import, file_path: nil)
    super(data_import)
    @file_path = file_path
  end

  def fetch
    rows = parse_sheet(target_sheet)
    rows.map { |row| apply_csv_mapping(row) }
  ensure
    cleanup
  end
end
```

The `parse_sheet` method reads creek's `simple_rows`, takes the first row as headers, and zips the rest into hashes:

```ruby
# lib/data_porter/sources/xlsx.rb (private)
def parse_sheet(sheet)
  rows = sheet.simple_rows.to_a
  return [] if rows.size <= 1

  headers = rows.first.values.map(&:to_s)
  rows.drop(1).map { |row| build_row(headers, row) }
end
```

Sheet selection is driven by `config["sheet_index"]`, defaulting to 0. The tempfile lifecycle is handled in `ensure` -- download, use, delete.

### Step 3 -- Registration and wiring

Three one-line changes to make the engine aware of XLSX:

```ruby
# lib/data_porter/sources.rb
REGISTRY = {
  api: Api, csv: Csv, json: Json, xlsx: Xlsx
}.freeze
```

```ruby
# app/models/data_porter/data_import.rb
validates :source_type, presence: true, inclusion: { in: %w[csv json api xlsx] }
```

```ruby
# lib/data_porter/configuration.rb
@enabled_sources = %i[csv json api xlsx]
```

The views get an updated hint: "CSV, JSON, or XLSX files accepted". That is the entire surface area of the change -- the rest of the pipeline (orchestrator, preview, import) works unchanged because every source returns the same `[{ key: value }]` format.

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| XLSX gem | creek | roo | Streaming, lower memory, read-only is all we need |
| Test injection | `file_path:` param | `content:` like CSV | Creek requires a file path; cannot parse a string |
| Tempfile cleanup | `ensure` block | Finalizer | Deterministic cleanup, no GC dependency |
| Sheet selection | `config["sheet_index"]` | Sheet name string | Simpler, integer index avoids encoding issues |

## Testing it

The specs mirror the CSV spec structure -- same target, same mapping, same assertions:

```ruby
# spec/data_porter/sources/xlsx_spec.rb
it "parses XLSX content and applies mapping" do
  source = described_class.new(data_import, file_path: fixture_path)
  rows = source.fetch

  expect(rows.size).to eq(2)
  expect(rows.first).to eq(
    first_name: "Alice", last_name: "Smith", email: "alice@example.com"
  )
end
```

Four specs covering: explicit mapping, auto-mapping, empty files, and sheet selection. All green alongside the existing 221.

```
225 examples, 0 failures
82 files inspected, no offenses detected
```

## Releasing v0.2.0

Adding a feature means bumping the version. Semver says: new functionality, backwards compatible = minor bump.

### Version bump

```ruby
# lib/data_porter/version.rb
VERSION = "0.2.0"
```

### CHANGELOG

A changelog is not optional for a maintained gem. We follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/):

```markdown
## [0.2.0] - 2026-02-07

### Added
- XLSX source powered by creek for streaming parsing
- Sheet selection via config["sheet_index"]

### Changed
- Default enabled_sources now includes :xlsx
- 225 RSpec examples (up from 221)
```

The format is mechanical: what was added, what changed, what was removed. No prose, no marketing. A developer scanning the changelog should know in five seconds whether this version affects them.

### The release checklist

For a gem like DataPorter, releasing is straightforward:

1. All specs green, rubocop clean
2. Version bumped in `version.rb`
3. CHANGELOG updated with the new version
4. README updated (source types, config defaults, new section)
5. Commit, tag, push, `gem push`

The discipline is in steps 3 and 4. Code changes are easy to remember. Documentation updates are easy to forget.

## Recap

- **XLSX source** added with creek, following the exact same pattern as CSV -- inherit from Base, implement `fetch`, return hashes.
- **creek** chosen over roo for streaming performance and minimal footprint.
- **Version bumped** to 0.2.0, CHANGELOG and README updated.
- **4 new specs**, 225 total, 0 failures.

## Next up

The XLSX source parses files with known headers. But what happens when the headers don't match? Next, we build interactive column mapping -- a UI where users drag source columns onto target columns before parsing. This is where the import workflow gets truly user-friendly.

---

*This is part 18 of the series "Building DataPorter". [Previous: Showcase & Final Retro](#) | [Next: Interactive Column Mapping](#)*
