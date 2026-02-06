# Task ID: 2

**Title:** Implement Configuration module

**Status:** pending

**Dependencies:** 1

**Priority:** high

**Description:** Create DataPorter::Configuration class with all config options and DataPorter.configure DSL. Options: parent_controller, queue_name, storage_service, cable_channel_prefix, context_builder, preview_limit, enabled_sources, scope.

**Details:**

Create lib/data_porter/configuration.rb with attr_accessors for: parent_controller (default: 'ApplicationController'), queue_name (default: :imports), storage_service (default: :local), cable_channel_prefix (default: 'data_porter'), context_builder (default: nil, accepts a lambda), preview_limit (default: 500), enabled_sources (default: [:csv, :json, :api]), scope (default: nil). Add DataPorter.configure class method yielding the config singleton, and DataPorter.configuration accessor.

**Test Strategy:**

Test default values. Test that configure block sets values correctly. Test that configuration is accessible via DataPorter.configuration.
