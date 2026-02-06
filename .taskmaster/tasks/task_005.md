# Task ID: 5

**Title:** Build Target DSL base class

**Status:** pending

**Dependencies:** 3, 4

**Priority:** high

**Description:** Implement DataPorter::Target base class with all DSL class methods: label, model, icon, sources, columns, csv_mapping, deduplicate_by, params, api_config. Include overridable instance hooks: transform, validate, persist, after_import, on_error.

**Details:**

Create lib/data_porter/target.rb. Implement class-level DSL using class_attribute or class instance variables with accessor methods: _label, _model, _icon, _sources, _columns, _csv_mappings, _dedup_keys, _params, _api_config, _dry_run_enabled, _rollback_enabled, _rollback_window, _rollback_strategy. Create DSL sub-modules in lib/data_porter/dsl/: columns_dsl.rb (Column struct with name, type, required, options, label), csv_mapping_dsl.rb, api_config_dsl.rb, params_dsl.rb. Default hook implementations: transform returns record unchanged, validate is no-op, persist raises NotImplementedError, after_import is no-op, on_error is no-op.

**Test Strategy:**

Test DSL methods set class attributes correctly. Test a sample target definition. Test default hooks. Test column definition with all options. Test inheritance of DSL attributes.
