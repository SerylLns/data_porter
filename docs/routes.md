---
title: Routes
icon: material/routes
---

# Routes

All routes are mounted under the engine's mount point. If you mount the engine at `/imports`:

```ruby
mount DataPorter::Engine, at: "/imports"
```

## Imports

| Method | Path | Action | Description |
|---|---|---|---|
| GET | `/imports` | index | List all imports |
| POST | `/imports` | create | Create a new import |
| GET | `/imports/:id` | show | Show import details |
| DELETE | `/imports/:id` | destroy | Delete an import |

## Import Actions

| Method | Path | Action | Description |
|---|---|---|---|
| GET | `/imports/:id/status` | status | JSON progress polling endpoint |
| PATCH | `/imports/:id/update_mapping` | update_mapping | Save column mapping |
| POST | `/imports/:id/parse` | parse | Parse the uploaded source |
| POST | `/imports/:id/confirm` | confirm | Run the import |
| POST | `/imports/:id/cancel` | cancel | Cancel a running import |
| POST | `/imports/:id/back_to_mapping` | back_to_mapping | Return to mapping step |
| POST | `/imports/:id/dry_run` | dry_run | Validate without persisting |
| GET | `/imports/:id/export_rejects` | export_rejects | Download rejected rows as CSV |

## Mapping Templates

| Method | Path | Action | Description |
|---|---|---|---|
| GET | `/mapping_templates` | index | List all templates |
| GET | `/mapping_templates/new` | new | New template form |
| POST | `/mapping_templates` | create | Create a template |
| GET | `/mapping_templates/:id/edit` | edit | Edit template form |
| PATCH | `/mapping_templates/:id` | update | Update a template |
| DELETE | `/mapping_templates/:id` | destroy | Delete a template |

## Status Endpoint

The `GET /imports/:id/status` endpoint returns JSON used by the Stimulus progress controller:

```json
{
  "status": "importing",
  "progress": {
    "current": 42,
    "total": 100,
    "percentage": 42
  }
}
```

The progress controller polls this endpoint every second and updates the UI with an animated progress bar. On completion, it triggers a page redirect via `Turbo.visit`.
