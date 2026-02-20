# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.3.0] - 2026-02-20

### Added

- **Webhooks** -- Per-target HTTP callbacks on import lifecycle events (`import.started`, `import.parsed`, `import.completed`, `import.failed`). Declarative DSL via `webhooks do webhook(url, events:, headers:, payload:) end`. HMAC-SHA256 request signing via `config.webhook_secret`. Async delivery via `WebhookJob` (fire-and-forget, 10s timeout). Custom payload lambdas and per-webhook headers supported

### Changed

- 508 RSpec examples (up from 466), 0 failures

## [2.2.0] - 2026-02-20

### Added

- **Column transformers** -- Declarative per-column transformation pipeline via `transform: [:strip, :downcase]` in the columns DSL. Applied automatically before the target's `transform` method. Ships with 9 built-in transformers (`strip`, `downcase`, `upcase`, `titleize`, `normalize_phone`, `parse_date`, `parse_boolean`, `parse_integer`, `parse_decimal`). Custom transformers via `DataPorter::ColumnTransformer.register(:name) { |v| ... }`

### Changed

- 466 RSpec examples (up from 438), 0 failures

## [2.1.1] - 2026-02-20

### Fixed

- **Route ordering** -- `mapping_templates` routes declared before the catch-all `imports` resource to prevent `/mapping_templates` from matching `imports#show`
- **Locale generator** -- Fixed `source_root` resolution so `copy_file` finds locale templates correctly
- **Locale generator** -- Added post-generation instructions (next steps message)

## [2.1.0] - 2026-02-20

### Added

- **i18n** -- All UI strings, error messages, and status labels are now translatable via Rails I18n. Ships with English and French locales (~100 keys each)
- **Locale generator** -- `rails g data_porter:locale fr` copies a locale file with all keys pre-filled for translation
- **Documentation site** -- MkDocs Material site with GitHub Pages deployment, search, dark mode, and full API reference
- **Progress labels via data attributes** -- Stimulus progress controller reads translated labels from the server instead of hardcoded JS strings

### Changed

- 438 RSpec examples (up from 423), 0 failures

## [2.0.0] - 2026-02-19

### Breaking

- **Default parent controller changed to `ActionController::Base`** -- Engine controllers no longer inherit from `ApplicationController` by default, avoiding conflicts with authorization gems (Pundit, CanCanCan, etc.). Set `config.parent_controller = "ApplicationController"` to restore the previous behavior
- **Engine routes mounted at root** -- `resources :imports` now uses `path: "/"` so the mount point controls the full URL (e.g. `mount DataPorter::Engine, at: "/imports"` gives `/imports`, not `/imports/imports`)

### Added

- **Back to mapping** -- `back_to_mapping` action resets a previewing import to the mapping step, preserving file headers and column mapping for re-mapping
- **Saved mapping persistence** -- Mapping form restores previously saved column mapping instead of resetting to defaults

### Changed

- 423 RSpec examples (up from 413), 0 failures

## [1.1.0] - 2026-02-08

### Added

- **Scoped imports** -- `config.scope` lambda returns the owner object (any ActiveRecord model) for multi-tenant isolation; used for both storage and filtering; IDOR-safe
- **Scoped mapping templates** -- Templates are filtered and assigned by owner, consistent with import scope
- **`ScopeManagement` concern** -- Shared `resolve_owner` logic extracted for both controllers
- **Polymorphic user on `mapping_templates`** -- Migration template adds `user` reference for template ownership

### Changed

- `build_import` uses `resolve_owner` instead of raw `current_user`
- 413 RSpec examples (up from 402), 0 failures

## [1.0.2] - 2026-02-07

### Changed

- Exclude `docs/` from gem package (194 KB → 80 KB)

## [1.0.1] - 2026-02-07

### Added

- **CSV delimiter auto-detection** -- Automatically detect `,` `;` `\t` separators via frequency analysis on the first line; explicit `col_sep` config still takes precedence
- **CSV encoding auto-detection** -- Detect and transcode Latin-1 / ISO-8859-1 content to UTF-8; strip UTF-8 BOM when present

### Fixed

- **`param.collection` accepts arrays** -- `Registry.serialize_param` now duck-types with `respond_to?(:call)` so both lambdas and plain arrays work
- **`dp-input` styling** -- Text inputs now share the same CSS rules as `dp-select` and `dp-file-input`
- **Migration template nullable user** -- Removed `null: false` from polymorphic `user` reference so the engine works without authentication
- **Skipped records visible in results** -- Added "Skipped" stat card for missing + partial records; title reflects errors; export rejects button includes all rejected rows
- **Hidden param label removed** -- `type: :hidden` params no longer render a label or wrapper div

### Changed

- 402 RSpec examples (up from 391), 0 failures

## [1.0.0] - 2026-02-07

### Added

- **Max records guard** -- `config.max_records` (default: 10,000) rejects files exceeding the limit before parsing
- **Transaction mode** -- `config.transaction_mode` (`:per_record` or `:all`); `:all` wraps entire import in a single transaction that rolls back on any failure
- **Fallback headers** -- Auto-generate `col_1, col_2...` when CSV/XLSX header row is empty
- **Reject rows CSV export** -- Download CSV of failed/errored records with original data + error messages after import; available when `errored_count > 0`
- **E2E specs** -- 6 end-to-end integration tests covering all source types (CSV, XLSX, JSON, API), import params, and reject rows export

### Fixed

- **Import params whitelist** -- `merge_import_params` now permits only param names declared in the Target DSL instead of using `permit!`
- **Column mapping whitelist** -- `permitted_column_mapping` filters mapping values to valid target column names; invalid values replaced with `""`
- **File size validation** -- Uploads exceeding `config.max_file_size` (default: 10 MB) are rejected before save
- **MIME type validation** -- Uploaded files must match allowed content types per source (CSV: `text/csv`, `text/plain`; JSON: `application/json`, `text/plain`; XLSX: OpenXML spreadsheet)
- **XSS in template form** -- Replaced `innerHTML` with safe DOM methods in `template_form_controller.js`

### Changed

- Validation chain refactored to `all_validations_pass?` using `.all?` to collect all errors at once instead of short-circuiting
- 391 RSpec examples (up from 354), 0 failures

## [0.9.0] - 2026-02-07

### Added

- **Import params DSL** -- Targets declare extra form fields via `params { param :hotel_id, type: :select, ... }` with support for `:select`, `:text`, `:number`, and `:hidden` types
- **`DSL::Param` struct** -- Stores param definitions (name, type, required, label, collection, default) with type validation
- **`import_params` accessor** -- Available in all target instance methods (`persist`, `transform`, `validate`, `after_import`, `on_error`), defaults to `{}`
- **Dynamic form rendering** -- Stimulus controller and inline JS dynamically render param fields when a target is selected, with default values and required indicators
- **Required params validation** -- Controller validates required import params on create, with error messages per missing field
- **Registry params serialization** -- `Registry.available` includes serialized param definitions with collection lambdas evaluated at call time

### Changed

- Controller concerns extracted into `ImportValidation`, `MappingManagement`, `RecordPagination`
- Orchestrator logic extracted into `RecordBuilder`, `Importer`, `DryRunner` modules
- Inline JS in `new.html.erb` extracted for consistency
- 354 RSpec examples (up from 313), 0 failures

## [0.6.0] - 2026-02-07

### Added

- **Records pagination** -- Preview and completed pages paginate records at 50 per page with Previous/Next navigation
- **Pagination component** -- Phlex `Shared::Pagination` with disabled states on first/last page and anchor scrolling to keep viewport on the table

### Changed

- 313 RSpec examples (up from 300), 0 failures

## [0.5.0] - 2026-02-07

### Added

- **JSON polling progress** -- Lightweight `GET /imports/:id/status` endpoint replaces ActionCable dependency for zero-config real-time progress tracking
- **Progress persistence** -- Orchestrator persists progress to `config["progress"]` via `update_column` for reliable status reporting
- **Dynamic progress labels** -- Progress bar shows contextual labels (Waiting, Parsing, Importing, Dry run) with animated gradient and shimmer effect
- **Results summary redesign** -- Completed imports show icon, stat cards (imported/errors), and duration
- **Imported records table** -- Completed import page displays the full records table
- **Submit button spinners** -- Confirm/Dry Run buttons disable and show spinner on click to prevent double submission
- **Import deletion** -- Delete button on completed/failed imports (index and show pages) with confirmation dialog
- **Automatic purge** -- `rake data_porter:purge` task removes completed/failed imports older than `purge_after` (default: 60 days)
- **`purge_after` configuration** -- Customizable retention period via `config.purge_after = 60.days` in initializer
- **Per-target source filtering** -- Source type dropdown filters to only show sources allowed by the selected target's `sources` DSL
- **Server-side source validation** -- Controller rejects source types not allowed by the target
- **Generator `--sources` option** -- `rails g data_porter:target Foo name:string --sources csv xlsx` generates target with specific sources

### Changed

- Confirm and dry_run actions set status to `pending` before enqueuing jobs to prevent race conditions
- Progress controller rewritten as JSON poller (1s interval) with auto-redirect via `Turbo.visit` on completion
- ResultsSummary component uses Unicode escapes for Phlex-safe icons
- 296 RSpec examples (up from 280), 0 failures

## [0.4.0] - 2026-02-07

### Added

- **Standalone engine layout** -- Self-contained HTML layout with importmap, loading Stimulus and Turbo from CDN. The engine no longer depends on the host app's layout or asset pipeline
- **Turbo Drive** -- All navigation within the engine is now handled by Turbo Drive for instant page transitions
- **Required field indication** -- Mapping form marks required target fields with `*` and shows a warning listing unmapped required fields
- **Duplicate mapping detection** -- Visual warning (orange border + message) when two file headers are mapped to the same target field
- **File validation on create** -- Controller-level validation rejects CSV/JSON/XLSX imports without a file attached, with error message displayed on the form
- **Hide save-as-template** -- The save-as-template checkbox is hidden when a mapping template is loaded
- **Import details card** -- Show page displays target, source type, file name, date, and record count

### Changed

- Mapping templates form rewritten with `<select>` elements for target fields instead of plain text inputs
- Templates index buttons styled as proper `dp-btn--secondary` / `dp-btn--danger`
- "Back to imports" moved to header as a button across all pages
- Progress controller uses `Turbo.visit` instead of `window.location.reload`
- ActionCable loaded via dynamic import with polling fallback (avoids CDN MIME type issues)
- Controllers return `422 Unprocessable Entity` on form validation errors for Turbo compatibility
- Rubocop limits relaxed: ClassLength 150, MethodLength 15
- 280 RSpec examples (up from 265), 0 failures

## [0.3.0] - 2026-02-07

### Added

- **Interactive column mapping** -- File-based imports (CSV/XLSX) now pause on a mapping step where users match file headers to target fields via dropdowns
- **Header extraction** -- New `ExtractHeadersJob` reads the first row of a file without parsing all data, with `extracting_headers` and `mapping` statuses
- **Dynamic mapping priority** -- User mapping (from UI) > code mapping (from Target DSL) > auto-map (parameterized headers)
- **`#headers` method** on `Sources::Csv` and `Sources::Xlsx` for lightweight first-row extraction
- **`#file_based?` helper** on `DataImport` to distinguish file sources from structured sources
- **MappingTemplate model** -- Persist reusable column mappings per target (`data_porter_mapping_templates` table)
- **MappingTemplatesController** -- Full CRUD for managing saved mapping templates
- **Mapping Phlex components** -- `Mapping::Form`, `Mapping::ColumnRow`, `Mapping::TemplateSelect` for the mapping UI
- **Stimulus mapping controller** -- Client-side template loading with zero network requests (reads `data-mapping` JSON attributes)
- **Save-as-template** -- Checkbox in the mapping form to save the current mapping for future imports
- **Badge styles** for `extracting_headers` and `mapping` statuses
- **Install generator** now creates `data_porter_mapping_templates` migration

### Changed

- CSS split from monolithic `application.css` into 10 domain-specific stylesheets (base, layout, table, badges, cards, preview, progress, alerts, modal, mapping)
- Phlex components reorganized into subdirectories: `Shared::`, `Preview::`, `Progress::`, `Mapping::`
- File-based imports route through `ExtractHeadersJob` instead of `ParseJob` on create
- `Orchestrator` gains `extract_headers!` method and `build_source` / `store_headers` helpers
- `Sources::Base#apply_csv_mapping` now checks three mapping sources in priority order
- 265 RSpec examples (up from 225), 0 failures

## [0.2.0] - 2026-02-07

### Added

- **XLSX source** -- Import Excel `.xlsx` files via `Sources::Xlsx`, powered by [creek](https://github.com/pythonicrubyist/creek) for streaming, memory-efficient parsing
- Sheet selection via `config["sheet_index"]` (defaults to first sheet)
- `creek` runtime dependency in gemspec

### Changed

- Default `enabled_sources` now includes `:xlsx` (`%i[csv json api xlsx]`)
- Dropzone hints updated to mention XLSX in both index and new import views
- 225 RSpec examples (up from 221), 0 failures

## [0.1.0] - 2026-02-06

### Added

- **Target DSL** -- Declarative class-level DSL (`label`, `model_name`, `columns`, `csv_mapping`, `deduplicate_by`, `dry_run_enabled`) with auto-registration via `Registry`
- **CSV source** -- Parse CSV files via ActiveStorage with header mapping and custom separators
- **JSON source** -- Parse JSON files with configurable `json_root` path extraction
- **API source** -- Fetch records from HTTP endpoints with dynamic `endpoint` and `headers` lambdas and `response_root` extraction
- **Orchestrator** -- Coordinates parse, import, and dry run workflows with per-record error handling
- **Dry run mode** -- Transaction-based validation that rolls back after testing all records against the database
- **Real-time progress** -- ActionCable broadcaster with Stimulus controller for live progress updates
- **Phlex UI components** -- StatusBadge, SummaryCards, PreviewTable, ProgressBar, ResultsSummary, FailureAlert (pure Ruby, no phlex-rails dependency)
- **ERB view templates** -- Index (with modal form and dropzone), new, and show pages composing Phlex components via `.call`
- **Plain CSS stylesheet** -- `dp-*` prefixed classes with CSS custom properties (`--dp-*`) for theming, auto-precompiled via Sprockets
- **StoreModel JSONB columns** -- ImportRecord, Error, and Report models stored as JSONB on the DataImport model
- **Install generator** -- Creates migration, initializer, routes mount, and `app/importers/` directory
- **Target generator** -- Scaffolds target classes with column parsing from CLI arguments
- **Configuration DSL** -- `DataPorter.configure` block with `parent_controller`, `queue_name`, `storage_service`, `cable_channel_prefix`, `context_builder`, `preview_limit`, `enabled_sources`
- **ActiveJob integration** -- ParseJob, ImportJob, DryRunJob with configurable queue name
- **221 RSpec examples** covering models, sources, orchestrator, jobs, channels, components, controllers, routes, generators, and views
