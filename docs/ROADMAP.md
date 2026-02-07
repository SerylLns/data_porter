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

---

## v2+ (future)

- Scoped imports (filter index by user/tenant)
- Webhooks / callbacks on import completion
- Batch persist (`insert_all` support)
- Resume / partial retry
- Scheduled imports (recurring API source)
- i18n
- Dashboard stats
