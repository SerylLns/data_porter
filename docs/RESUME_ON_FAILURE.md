# Resume on Failure — v2.6.0

## Overview

When an import fails mid-way (crash, timeout, exception), the user can
**resume from where it stopped** instead of re-importing from scratch.

Progress checkpoints are stored in the existing `config` JSONB column
alongside `broadcast_progress` — zero additional DB operations.

## Implementation Steps

### Commit 1 — Fix `handle_failure` (preserve report)
- [x] Spec: `handle_failure` keeps existing report data
- [x] Fix: merge error into existing report instead of creating a new one

### Commits 2+3 — `broadcast_progress` checkpoint + wire per-record
- [x] Spec: checkpoint written to config when results passed
- [x] Spec: no checkpoint when results omitted (parse, dry_run)
- [x] Add `save_checkpoint` private method + `pct` helper
- [x] Add optional `results:` keyword to `broadcast_progress`
- [x] Wire `results:` in `import_per_record` loop

### Commit 4 — Pass `results:` in `import_bulk`
- [x] Spec: checkpoint updated after each batch
- [x] Extract `process_batches` to respect 10-line method limit

### Commit 5 — Model: `resumable?` + update `reset_to_mapping!`
- [x] Spec: `resumable?` returns true when failed + checkpoint exists
- [x] Spec: `resumable?` returns false when no checkpoint / zero processed / not failed
- [x] Spec: `reset_to_mapping!` clears checkpoint
- [x] Implement `resumable?`
- [x] Update `reset_to_mapping!` to `.except("progress", "checkpoint")`

### Commit 6 — Resume logic in `import_per_record`
- [x] Spec: resume skips already-processed records
- [x] Spec: fresh import (no checkpoint) processes all records
- [x] Spec: results seeded from checkpoint counts
- [x] Spec: checkpoint cleared after successful completion
- [x] Spec: checkpoint preserved on catastrophic failure
- [x] Implement `load_checkpoint`, `seed_results`, `clear_checkpoint`
- [x] Update `import_per_record` to use checkpoint

### Commit 7 — Resume logic in `import_bulk`
- [x] Spec: resume skips already-processed batches
- [x] Spec: seeds bulk results from checkpoint counts
- [x] Spec: checkpoint preserved on catastrophic bulk failure
- [x] Implement checkpoint logic in `import_bulk` with `@bulk_state`

### Commit 8 — Controller `resume` action + route
- [x] Spec: `resume` action defined
- [x] Spec: route registered
- [x] Add `resume` action to `ImportsController`
- [x] Add `post :resume` route

### Commit 9+10 — UI + Locales
- [x] Resume button visible when `resumable?`
- [x] Retry button demoted to secondary
- [x] Add `resume` key to en.yml and fr.yml
- [x] 573 specs passing, 0 rubocop offenses

## Known Limitations (v1)

### Bulk mode: up to 1 batch of duplicates on resume

In per-record mode, the checkpoint is written after **each record**.
The duplicate window is negligible (microseconds between persist and checkpoint write).

In bulk mode, the checkpoint is written after **each completed batch**.
If a crash occurs mid-batch:

```
Batch 2001-2500 (batch_size: 500)
  -> 350 records persisted in DB
  -> crash at record 351
  -> broadcast_progress never reached -> checkpoint stays at 2000
  -> resume replays the entire batch 2001-2500
  -> 350 records are duplicated
```

**Maximum duplicate risk**: 1 batch (= `batch_size` records).

**Mitigation strategies for host apps**:
- Use DB uniqueness constraints on the target table
- Make `persist_batch` idempotent (upsert / `ON CONFLICT`)
- Use smaller batch sizes to reduce the window

A future version may introduce intra-batch checkpointing or
transactional batches to eliminate this risk entirely.

## Blog Coverage

This feature will likely span **2 blog articles**:
- **Part A**: Checkpoint mechanism + per-record resume (commits 1-6)
- **Part B**: Bulk resume + controller/UI + edge cases (commits 7-10)
