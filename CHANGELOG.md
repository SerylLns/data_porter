# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
