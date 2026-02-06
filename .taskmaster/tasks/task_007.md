# Task ID: 7

**Title:** Create DataImport model and migration

**Status:** pending

**Dependencies:** 3, 6

**Priority:** high

**Description:** Implement DataPorter::DataImport ActiveRecord model with enum status, JSONB attributes (records, report, config), ActiveStorage file attachment, polymorphic user association. Create the migration template.

**Details:**

Create app/models/data_porter/data_import.rb with: table_name 'data_porter_imports', belongs_to :user (polymorphic), has_one_attached :file, enum :status (pending:0, parsing:1, previewing:2, importing:3, completed:4, failed:5, dry_running:6, rolling_back:7, rolled_back:8), StoreModel attributes for records and report, serialized config. Add validations for target_key and source_type. Implement helper methods: target_class, source_class, previewable?, importable_records, records_summary. Create migration template in lib/generators/data_porter/templates/ with proper schema (target_key, source_type, status, records JSONB, report JSONB, config JSONB, user polymorphic refs, timestamps, indexes).

**Test Strategy:**

Test enum values. Test validations. Test helper methods. Test StoreModel attribute types. Test associations.
