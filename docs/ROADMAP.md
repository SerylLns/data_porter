# Roadmap

## v1.0 — Production-ready

The goal is a gem that handles real-world imports reliably at scale.

### 1. Records pagination

**Problem:** All parsed records are stored in a single JSONB column (`records`).
A 10k-row CSV generates 50-100 MB in one row. This is a scalability blocker.

**Solution:** Paginate preview and completed pages, and consider streaming
records to avoid loading everything in memory.

**Scope:**
- Paginated preview table (configurable page size)
- Paginated completed results table
- Limit records loaded in controller (not all at once)
- Consider moving records to a separate table for large imports

### ~~2. Import params~~ DONE

Implemented in v0.7.0. Targets declare `params` with a DSL (`:select`, `:text`,
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
