# Roadmap

## v2.0 - Planned

### High Priority

#### XLSX Source
- Parse `.xlsx` files natively (via `creek` or `roo` gem)
- Sheet selector when the file contains multiple sheets
- Same parsing pipeline as CSV (prerequisite for column mapping)

#### Interactive Column Mapping & Templates
- Mapping UI on the preview step: each CSV/XLSX column header gets a dropdown to select the target field
- Auto-suggest based on column name similarity
- Save mapping as a reusable template (name + column-to-field pairs)
- Template selector that pre-fills all dropdowns at once
- Stored per-target so each import type has its own template library

#### Export (reverse workflow)
- `ExportTarget` DSL mirroring the import Target
- Define query scope, columns, and output format (CSV, JSON, XLSX)
- Background job with progress bar (reuse existing ActionCable infrastructure)
- Download link on completion

#### Batch Import
- Process large files in configurable batches (default: 1,000 records)
- Use `insert_all` / `upsert_all` for bulk persistence
- Granular progress: "12,000 / 150,000 records"
- Memory-efficient streaming parser for CSV and XLSX

#### Scheduled Imports
- Cron-like configuration in the Target DSL: `schedule "0 3 * * *"`
- Recurring API source imports (fetch external data on a timer)
- Dashboard for scheduled imports with last run status and next run time
- Built on ActiveJob + `solid_queue` or host app's queue adapter

### Medium Priority

#### Column Transformers
- Inline transform lambdas in the column DSL
- Built-in transformers: `downcase`, `strip`, `normalize_phone`, `parse_date`
```ruby
column :email, type: :email, transform: ->(v) { v.downcase.strip }
```

#### Diff Mode
- Compare incoming records with existing database data
- Show what will be created, updated, or left unchanged
- Visual diff on the preview step before confirming
- Supports `deduplicate_by` keys for record matching

#### Webhooks
- Notify an external URL on import completion or failure
- Configurable per-target or globally
- JSON payload with import summary and error details

#### Import API (REST)
- `POST /data_porter/api/imports` to trigger imports programmatically
- Accept file upload or source URL
- JSON response with import ID for status polling

### Low Priority

#### Dashboard Analytics
- Stats: imports per week, error rate, average duration, top targets
- Lightweight charts (inline SVG, no JS dependency)

#### Rollback
- Undo a completed import (soft-delete created records)
- Uses `target_id` already tracked on each ImportRecord
- Confirmation step with summary of records to be reverted
