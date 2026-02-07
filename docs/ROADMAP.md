# Roadmap

## v1.0 — Production-ready

The goal is a gem that handles real-world imports reliably at scale.

### ~~1. Records pagination~~ DONE

Implemented in v0.6.0. Preview and completed pages are paginated (50 per page).
Controller limits records loaded via `RecordPagination` concern.

### ~~2. Import params~~ DONE

Implemented in v0.9.0. Targets declare `params` with a DSL (`:select`, `:text`,
`:number`, `:hidden`). Values stored in `config["import_params"]`, accessible
via `import_params` in all target instance methods. See [Targets docs](TARGETS.md#params--).

### ~~3. Security audit~~ DONE

- Replaced `permit!` on import params and column mapping with whitelists
- File size validation (`config.max_file_size`, default 10 MB)
- MIME type validation per source type
- XSS fix in template form controller (safe DOM methods)

### ~~4. Safety guards~~ DONE

- Max records guard (`config.max_records`, default 10,000)
- Transaction mode (`config.transaction_mode`: `:per_record` or `:all`)
- Fallback headers (auto-generate `col_1, col_2...` for empty header rows)

### ~~5. Reject rows export~~ DONE

Download CSV of failed/errored records with original data + error messages.
Zero-dependency streaming via `send_data`.

### ~~6. E2E integration tests~~ DONE

6 end-to-end specs covering all source types (CSV, XLSX, JSON, API),
import params flow, and reject rows CSV export. 391 specs total.

---

## v1.1 — Quality of life

### Column mapping for JSON and API sources

The interactive column mapping step currently only works for file-based sources
(CSV, XLSX). JSON and API sources have stable, predictable keys that rarely need
remapping, but supporting mapping for all sources would provide a consistent UX.

### Bug fixes from manual testing

- `dp-input` CSS styling (text inputs matched select appearance)
- `param.collection` accepts both lambdas and plain arrays
- Migration template: nullable user reference (allows engine without authentication)
- Results summary: show skipped count (missing + partial) alongside imported/errored
- Export rejects button: show when any records were rejected, not just persist errors

---

## v2+ (future)

- Dry-run performance estimate ("Estimated import time: ~2m30s")
- Auto-map heuristics: tokenized header match + synonyms (email → email_address)
- Scoped imports (filter index by user/tenant)
- Webhooks / callbacks on import completion
- Batch persist (`insert_all` support)
- Resume / partial retry
- Scheduled imports (recurring API source)
- i18n
- Dashboard stats
