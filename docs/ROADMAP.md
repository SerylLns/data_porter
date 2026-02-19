---
title: Roadmap
icon: material/map-marker-path
---

# Roadmap

## v1.0 — Production-ready DONE

The goal is a gem that handles real-world imports reliably at scale.

### ~~1. Records pagination~~ DONE

Implemented in v0.6.0. Preview and completed pages are paginated (50 per page).
Controller limits records loaded via `RecordPagination` concern.

### ~~2. Import params~~ DONE

Implemented in v0.9.0. Targets declare `params` with a DSL (`:select`, `:text`,
`:number`, `:hidden`). Values stored in `config["import_params"]`, accessible
via `import_params` in all target instance methods. See [Targets docs](TARGETS.md#params).

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
import params flow, and reject rows CSV export. 395 specs total.

---

## v1.1 — Deploy-ready

Priority: features required to deploy DataPorter to real users.

### ~~Scoped imports~~ DONE

Implemented in v1.1.0. `config.scope` returns the owner object for both storage
and filtering. Works with any polymorphic model (User, Hotel, Organization...):

```ruby
config.scope = ->(user) { user }          # per-user
config.scope = ->(user) { user.hotel }    # per-hotel
```

### ~~Preview ↔ Mapping navigation~~ DONE

Implemented. Users can go back from preview to the mapping step and adjust
column mapping without restarting the import.

### ~~CSV auto-detect: delimiter & encoding~~ DONE

Implemented in v1.0.1. Auto-detect CSV delimiter (`,` `;` `\t`) via frequency
analysis on the first line. Auto-detect file encoding: strip UTF-8 BOM, validate
UTF-8, fallback to ISO-8859-1 transcoding. Explicit `col_sep` config takes
precedence.

### Column mapping for JSON and API sources

The interactive column mapping step currently only works for file-based sources
(CSV, XLSX). JSON and API sources have stable, predictable keys that rarely need
remapping, but supporting mapping for all sources would provide a consistent UX.

---

## v1.2 — Smart imports

### Dry-run performance estimate

After a dry run, display an estimated import time based on average record
processing speed: "Estimated import time: ~2m30s". Helps users decide whether
to launch the import now or schedule it for off-peak hours.

### Permissions / RBAC

Role-based access control for import operations. Allow host apps to restrict
who can create imports, confirm imports, or access specific targets. Integrate
with existing authorization frameworks (Pundit, CanCanCan) via a configurable
policy hook.

### Column transformers

Built-in transformation pipeline applied per-column before the target's
`transform` method. Declarative DSL in the target:

```ruby
columns do
  column :email, type: :email, transform: [:strip, :downcase]
  column :phone, type: :string, transform: [:strip, :normalize_phone]
  column :born_on, type: :date, transform: [:parse_date]
end
```

Ships with common transformers (`strip`, `downcase`, `titleize`,
`normalize_phone`, `parse_date`). Custom transformers via a registry.

### Auto-map heuristics

Smart column mapping suggestions using tokenized header matching and synonym
dictionaries. When a CSV has "E-mail Address", auto-suggest mapping to `:email`.
Built-in synonyms for common patterns (phone → phone_number,
first name → first_name). Configurable synonym lists per target.

---

## v2.0 — Scale & Automation

### Bulk import

High-volume import support using `insert_all` / `upsert_all` for batch
persistence. Bypass per-record `persist` calls when the target opts in,
enabling 10-100x throughput for simple create/upsert scenarios. Configurable
batch size, with fallback to per-record mode on conflict.

### Update & diff mode

Support update (upsert) imports alongside create-only. Given a
`deduplicate_by` key, detect existing records and show a diff preview:
new records, changed fields (highlighted), unchanged rows. User confirms
which changes to apply. Enables recurring data sync workflows.

### Resume / retry on failure

If an import fails mid-way (timeout, crash, transient error), resume from
the last successful record instead of restarting from scratch. Track a
checkpoint index in the report. Critical for large imports (5k+ records)
where re-processing everything is not acceptable.

### API pagination

Support paginated API sources. The current API source does a single GET,
which works for small datasets but not for APIs returning thousands of
records across multiple pages. Support offset, cursor, and link-header
pagination strategies via `api_config`:

```ruby
api_config do
  endpoint "https://api.example.com/contacts"
  pagination :cursor, param: "after", root: "data", next_key: "meta.next_cursor"
end
```

### Scheduled imports

Recurring imports from API or remote sources on a cron schedule. A target
declares a schedule, and DataPorter automatically fetches and imports at
the configured interval. Built on ActiveJob with configurable queue.

---

## v3.0 — Platform

### Webhooks

HTTP callbacks on import lifecycle events (started, completed, failed).
Configurable per-target with URL, headers, and payload template. Enables
integration with Slack notifications, CI pipelines, or external dashboards.

### External connectors

Source plugins beyond local files and HTTP APIs:

- **Google Sheets** — OAuth2 + Sheets API, treat a spreadsheet as a source
- **SFTP** — Poll a remote directory for new files
- **AWS S3** — Watch a bucket/prefix for uploads
- **Remote HTTP polling** — Periodically fetch from a paginated API

Each connector implements the `Sources::Base` interface. Installed as
optional companion gems (`data_porter-google_sheets`, `data_porter-s3`).

### i18n

Full internationalization of all UI strings, error messages, and status
labels. Ship with English and French translations. Host apps can override
or add languages via standard Rails I18n.

### Dashboard & analytics

Import statistics dashboard: success rates, average duration, records per
import, most-used targets, failure trends. Mountable as an admin-only route.
