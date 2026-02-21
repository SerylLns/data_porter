---
title: Advanced
icon: material/rocket-launch
---

# Advanced

## Bulk Import

For high-volume imports (1k-10k+ records), the default per-record persistence can be slow: one DB call and one progress broadcast per row. Bulk mode uses `insert_all` for 10-100x throughput on simple create scenarios.

Bulk mode is **opt-in per target** -- existing targets are unaffected.

### Basic usage

Add `bulk_mode` to your target. The default `persist_batch` calls `insert_all` on the model class:

```ruby
class GuestTarget < DataPorter::Target
  label "Guests"
  model_name "Guest"
  sources :csv
  bulk_mode batch_size: 500

  columns do
    column :first_name, type: :string, required: true
    column :last_name,  type: :string
    column :email,      type: :email
  end

  def persist(record, context:)
    Guest.create!(record.attributes)
  end
end
```

`persist` is still required as a fallback (see [conflict strategies](#conflict-strategies) below).

The default `persist_batch` automatically injects `created_at` and `updated_at` timestamps into each row.

### Options

```ruby
bulk_mode batch_size: 500, on_conflict: :retry_per_record
```

| Option | Default | Description |
|---|---|---|
| `batch_size` | `500` | Number of records per `insert_all` call |
| `on_conflict` | `:retry_per_record` | What to do when a batch fails |

### Conflict strategies

When a batch fails (e.g. a unique constraint violation), the `on_conflict` option controls what happens:

| Strategy | Behavior |
|---|---|
| `:retry_per_record` | Re-process the failed batch record-by-record via `persist`. Records that succeed are counted as created; records that fail are counted as errored. This is the safest default. |
| `:fail_batch` | Mark all records in the failed batch as errored. No individual retry. Use this when you want fast failure and don't need partial recovery. |

### Custom batch logic

Override `persist_batch` for full control over batch persistence. This is useful for `upsert_all`, custom conflict handling, or injecting extra data:

```ruby
class OrderTarget < DataPorter::Target
  label "Orders"
  model_name "Order"
  sources :csv
  bulk_mode batch_size: 200, on_conflict: :fail_batch

  columns do
    column :external_id, type: :string, required: true
    column :total,       type: :decimal
  end

  def persist_batch(records, context:)
    Order.upsert_all(
      records.map { |r| r.data.merge("shop_id" => import_params["shop_id"]) },
      unique_by: :external_id
    )
  end

  def persist(record, context:)
    Order.create!(record.data.merge("shop_id" => import_params["shop_id"]))
  end
end
```

!!! note
    When overriding `persist_batch`, you are responsible for handling timestamps and any extra attributes. The auto-injected `created_at`/`updated_at` only applies to the default implementation.

### How it works

1. After parsing, importable records are sliced into batches of `batch_size`
2. Each batch is passed to `persist_batch` (custom or default `insert_all`)
3. On success, all records in the batch are counted as created
4. On failure, the conflict strategy kicks in (retry or fail)
5. Progress is broadcast once per batch, not per record
6. Transform and validate still run per-record during the parse phase (unchanged)

### Performance tips

- **Batch size**: 500 is a good default. Going above 1,000 may lock the table for too long or stress the database WAL. Going below 100 reduces the throughput benefit.
- **Indexes**: Ensure your table has the right indexes for `insert_all` / `upsert_all` (especially `unique_by` columns).
- **No ActiveRecord callbacks**: `insert_all` bypasses validations, callbacks (`before_save`, `after_create`, etc.), and Ruby-level defaults. All validation should happen in the parse phase via column types and `validate`. If you need callbacks, override `persist_batch` with `create!` calls or use the default per-record mode.
- **Memory**: Records are processed lazily in batches -- only one batch is in memory at a time during the import phase.
