# Task ID: 3

**Title:** Create StoreModels (ImportRecord, Error, Report)

**Status:** pending

**Dependencies:** 1

**Priority:** high

**Description:** Implement the three StoreModel classes for JSONB storage: ImportRecord (line_number, status, data, errors_list, warnings, target_id), Error (message), Report (records_count, complete_count, partial_count, missing_count, duplicate_count, imported_count, errored_count, error_reports).

**Details:**

Create lib/data_porter/store_models/error.rb with StoreModel::Model including attribute :message. Create lib/data_porter/store_models/import_record.rb with attributes: line_number (:integer), status (:string, default: 'pending'), data (:json, default: {}), errors_list (Error.to_array_type), warnings (Error.to_array_type), target_id (:integer), dry_run_passed (:boolean, default: false). Include STATUSES constant, helper methods (complete?, importable?, add_error, add_warning, attributes), and run_validations! method with validate_required_columns!, validate_types!, validate_inclusions!, check_duplicates!, determine_status!. Create lib/data_porter/store_models/report.rb with all count attributes.

**Test Strategy:**

Test each StoreModel initializes with defaults. Test ImportRecord validation methods. Test status determination logic. Test add_error and add_warning methods.
