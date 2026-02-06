# Task ID: 17

**Title:** Write RSpec test suite for core modules

**Status:** pending

**Dependencies:** 9

**Priority:** high

**Description:** Create comprehensive RSpec tests for all core modules: Configuration, StoreModels, TypeValidator, Target DSL, Registry, Sources, Orchestrator, DataImport model.

**Details:**

Set up spec/spec_helper.rb with proper requires and test configuration. Create specs: spec/data_porter/configuration_spec.rb, spec/data_porter/store_models/import_record_spec.rb, spec/data_porter/store_models/error_spec.rb, spec/data_porter/store_models/report_spec.rb, spec/data_porter/type_validator_spec.rb, spec/data_porter/target_spec.rb (test DSL), spec/data_porter/registry_spec.rb, spec/data_porter/sources/csv_spec.rb, spec/data_porter/orchestrator_spec.rb, spec/models/data_porter/data_import_spec.rb. Use fixtures or factories for test data. Mock ActiveStorage for file tests.

**Test Strategy:**

Run bundle exec rspec and verify all tests pass. Aim for high coverage of business logic.
