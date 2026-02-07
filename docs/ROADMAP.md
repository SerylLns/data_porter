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

### 2. Import params (additionable params)

**Problem:** Scoped imports (e.g., importing guests for a specific hotel) require
adding a parent ID column to every CSV row. This is tedious and error-prone.

**Solution:** A `params` DSL on Target that declares extra fields shown in the
new import form. Values are stored in `config["params"]` and available via
`import_params` in target instance methods.

**API design:**
```ruby
class GuestTarget < DataPorter::Target
  params do
    param :hotel_id, type: :select, label: "Hotel", required: true,
          collection: -> { Hotel.pluck(:name, :id) }
  end

  def persist(record, context:)
    Guest.create!(record.attributes.merge(hotel_id: import_params[:hotel_id]))
  end
end
```

**Supported types:** `:select`, `:text`, `:number`, `:hidden`

**Blog article:** Planned (Part 2 series)

---

## v2+ (future)

- Scoped imports (filter index by user/tenant)
- Webhooks / callbacks on import completion
- Batch persist (`insert_all` support)
- Resume / partial retry
- Scheduled imports (recurring API source)
- i18n
- Dashboard stats
