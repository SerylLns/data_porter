# Roadmap

## Next

### i18n

Full internationalization of all UI strings, error messages, and status labels. Ship with English and French translations. Host apps can override or add languages via standard Rails I18n.

### Column transformers

Built-in transformation pipeline applied per-column before the target's `transform` method. Declarative DSL in the target:

```ruby
columns do
  column :email, type: :string, transform: [:strip, :downcase]
  column :phone, type: :string, transform: [:strip, :normalize_phone]
  column :born_on, type: :date, transform: [:parse_date]
end
```

Ships with common transformers (`strip`, `downcase`, `titleize`, `normalize_phone`, `parse_date`). Custom transformers via a registry.

### Webhooks

HTTP callbacks on import lifecycle events (started, completed, failed). Configurable per-target with URL, headers, and payload template. Enables integration with Slack notifications, CI pipelines, or external dashboards.

---

## Planned

### Bulk import

High-volume import support using `insert_all` / `upsert_all` for batch persistence. Opt-in per target to bypass per-record `persist` calls, enabling 10-100x throughput for simple create/upsert scenarios. Configurable batch size, with fallback to per-record mode on conflict.

### Update & diff mode

Support update (upsert) imports alongside create-only. Given a `deduplicate_by` key, detect existing records and show a diff preview: new records, changed fields (highlighted), unchanged rows. User confirms which changes to apply. Enables recurring data sync workflows.

### Resume / retry on failure

If an import fails mid-way (timeout, crash, transient error), resume from the last successful record instead of restarting from scratch. Track a checkpoint index in the report. Critical for large imports (5k+ records) where re-processing everything is not acceptable.

### API pagination

Support paginated API sources. The current API source does a single GET, which works for small datasets but not for APIs returning thousands of records across multiple pages. Support offset, cursor, and link-header pagination strategies via `api_config`:

```ruby
api_config do
  endpoint "https://api.example.com/contacts"
  pagination :cursor, param: "after", root: "data", next_key: "meta.next_cursor"
end
```

### Import API (REST)

Headless REST API for programmatic imports:

- `POST /api/imports` — create import (multipart file upload or JSON payload)
- `GET /api/imports/:id` — status + results
- Auth via `config.api_authenticate` lambda (API key or Bearer token)
- Reuses existing job pipeline (parse, import, dry run)

### View generator & theming

Customizable UI in two layers:

- **View generator** — `rails g data_porter:views` copies the 7 ERB templates into the host app for structural customization (layout, buttons, sections). Similar to `devise:views`.
- **CSS theming** — All styles use `--dp-*` custom properties. Host apps override variables to match their design system, no ERB changes needed.
- **Light / dark mode** — Two built-in presets toggled via `prefers-color-scheme` or a `.dp-dark` class.

### Auto-map heuristics

Smart column mapping suggestions using tokenized header matching and synonym dictionaries. When a CSV has "E-mail Address", auto-suggest mapping to `:email`. Built-in synonyms for common patterns (phone → phone_number, first name → first_name). Configurable synonym lists per target.

---

## Ideas

### Export (reverse workflow)

`ExportTarget` DSL mirroring the import Target. Define query scope, columns, and output format (CSV, JSON, XLSX). Background job with progress bar and download link on completion.

### External connectors

Source plugins beyond local files and HTTP APIs:

- **Google Sheets** — OAuth2 + Sheets API, treat a spreadsheet as a source
- **SFTP** — Poll a remote directory for new files
- **AWS S3** — Watch a bucket/prefix for uploads

Each connector implements the `Sources::Base` interface. Installed as optional companion gems (`data_porter-google_sheets`, `data_porter-s3`).

### Scheduled imports

Recurring imports from API or remote sources on a cron schedule. A target declares a schedule, and DataPorter automatically fetches and imports at the configured interval. Built on ActiveJob with configurable queue.

### Rollback

Undo a completed import by soft-deleting the created records. Confirmation step with summary of records to be reverted.

### Dashboard & analytics

Import statistics dashboard: success rates, average duration, records per import, most-used targets, failure trends. Mountable as an admin-only route.
