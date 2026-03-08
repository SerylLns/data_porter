---
title: Column Mapping
icon: material/swap-horizontal
---

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
3. **Auto-map** -- heuristic matching using exact names and synonyms

Non-file sources (JSON, API) skip the mapping step entirely.

## Auto-Map Heuristics

When no user mapping or code mapping exists for a column, DataPorter attempts to auto-map file headers to target fields. The matching works in two steps:

1. **Exact match** -- normalize the header (lowercase, underscores) and compare to column names. `"First Name"` matches `first_name`.
2. **Synonym match** -- look up the normalized header in a built-in synonym table. `"E-mail Address"` matches `email`, `"fname"` matches `first_name`.

### Built-in synonyms

DataPorter ships with synonyms for common fields:

| Column | Recognized synonyms |
|---|---|
| `email` | email, e_mail, email_address, courriel, mail |
| `first_name` | firstname, fname, first, prenom |
| `last_name` | lastname, lname, last, nom |
| `phone_number` | phone, tel, telephone, mobile, cell |
| `address` | addr, street, adresse |
| `city` | ville, town |
| `zip_code` | zip, postal_code, postcode, code_postal |
| `country` | pays, nation |
| `company` | company_name, organization, organisation, entreprise, societe |

See `DataPorter::AutoMapper::SYNONYMS` for the full list.

### Custom synonyms

Add per-column synonyms via the `synonyms:` keyword in the column DSL:

```ruby
columns do
  column :email, type: :string, synonyms: %w[correo e_posta]
  column :room_number, type: :string, synonyms: %w[chambre room_no]
end
```

Custom synonyms are merged with the built-in list -- they extend, not replace.
