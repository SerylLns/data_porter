# Roadmap

## Completed

### v0.2.0 -- XLSX Source
- ~~Parse `.xlsx` files natively via `creek` gem~~
- ~~Sheet selector via `config["sheet_index"]`~~
- ~~Same parsing pipeline as CSV~~

### v0.3.0 -- Interactive Column Mapping & Templates
- ~~Mapping UI: each CSV/XLSX column header gets a dropdown to select the target field~~
- ~~Save mapping as a reusable template (name + column-to-field pairs)~~
- ~~Template selector that pre-fills all dropdowns at once~~
- ~~Stored per-target so each import type has its own template library~~
- ~~Header extraction step before parsing for file-based sources~~
- ~~Dynamic mapping priority: user mapping > code mapping > auto-map~~

### v0.4.0 -- Standalone Engine UX
- ~~Self-contained layout with Stimulus + Turbo Drive via CDN importmap~~
- ~~Required field indication and duplicate mapping detection~~
- ~~File validation on create for file-based sources~~
- ~~Turbo Drive for instant page navigation~~
- ~~Import details card on show page~~
- ~~Improved template management UI~~

---

## Planned

### High Priority

#### Required Fields in New Import Form
- Validate required import params (`target.params`) on the new import form
- Client-side: disable submit until required fields are filled
- Server-side: reject creation if required params are missing

#### Export (reverse workflow)
- `ExportTarget` DSL mirroring the import Target
- Define query scope, columns, and output format (CSV, JSON, XLSX)
- Background job with progress bar (reuse existing ActionCable infrastructure)
- Download link on completion

#### Batch Import & Resumable Jobs
- Process large files in configurable batches (default: 1,000 records)
- Use `insert_all` / `upsert_all` for bulk persistence
- Granular progress: "12,000 / 150,000 records"
- Memory-efficient streaming parser for CSV and XLSX
- Resumable imports: save cursor position, resume on worker restart
- Explore `ActiveJob::Continuable` (Rails 8.1+) with fallback mechanism for Rails 7.x
- Ref: https://codewithrails.com/blog/rails-resumable-csv-import-continuable/

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

#### Auto-suggest Mapping
- Fuzzy matching between file headers and target columns
- Suggest mappings based on Levenshtein distance or string similarity
- Pre-fill dropdowns with best guesses, user confirms

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
- `POST /api/imports` -- create import (multipart file upload or JSON payload)
- `GET /api/imports` -- list imports (paginated)
- `GET /api/imports/:id` -- status + results
- `DELETE /api/imports/:id` -- delete import
- Auth via `config.api_authenticate` lambda (API key or Bearer token)
- Reuses existing job pipeline (parse, import, dry run)
- Simple JSON serialization (no Graphiti dependency)

#### I18n
- Extract all hardcoded strings from ERB views and Phlex components to locale files
- Ship `config/locales/en.yml` as default
- Users can override with their own locale files or add translations

### Low Priority

#### Dashboard Analytics
- Stats: imports per week, error rate, average duration, top targets
- Lightweight charts (inline SVG, no JS dependency)

#### Rollback
- Undo a completed import (soft-delete created records)
- Uses `target_id` already tracked on each ImportRecord
- Confirmation step with summary of records to be reverted
