# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
