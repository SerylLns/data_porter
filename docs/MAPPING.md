# Column Mapping

For file-based sources (CSV/XLSX), DataPorter adds an interactive mapping step between upload and parsing. Users see their file's actual column headers and map each one to a target field via dropdowns.

```
File Header          Target Field
+-----------+        +---------------+
| Prenom    |   ->   | First Name  v |
+-----------+        +---------------+
+-----------+        +---------------+
| Nom       |   ->   | Last Name   v |
+-----------+        +---------------+
```

Dropdowns are pre-filled from the Target's `csv_mapping` when headers match. Users can adjust any mapping before continuing to the preview step.

## Required fields

Required target fields are marked with `*` in the dropdown labels. If any required field is left unmapped, a warning banner appears listing the missing fields. This validation is client-side only -- it warns but does not block submission.

## Duplicate detection

If two file headers are mapped to the same target field, the affected rows are highlighted with an orange border and a warning message appears. This helps catch accidental duplicate mappings before parsing.

## Mapping Templates

Mappings can be saved as reusable templates. When starting a new import, users select a saved template from a dropdown to auto-fill all column mappings at once. Templates are stored per-target, so each import type has its own template library.

### Managing templates

- **Inline**: Check "Save as template" in the mapping form and give it a name
- **CRUD**: Use the "Mapping Templates" link on the imports index page to create, edit, and delete templates

When a template is loaded, the "Save as template" checkbox is hidden since the user is already working from an existing template.

## Mapping Priority

When parsing, mappings are resolved in priority order:

1. **User mapping** -- from the mapping UI (`config["column_mapping"]`)
2. **Code mapping** -- from the Target DSL (`csv_mapping`)
3. **Auto-map** -- parameterize headers to match column names

Non-file sources (JSON, API) skip the mapping step entirely.
