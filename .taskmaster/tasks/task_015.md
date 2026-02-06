# Task ID: 15

**Title:** Create install generator

**Status:** pending

**Dependencies:** 7, 2

**Priority:** medium

**Description:** Implement rails generate data_porter:install generator that creates migration, initializer, importers directory, and mounts the engine in routes.

**Details:**

Create lib/generators/data_porter/install_generator.rb. It should: copy migration template (create_data_porter_imports) with proper timestamp, create config/initializers/data_porter.rb with commented configuration options, create empty app/importers/ directory, inject mount DataPorter::Engine at: '/imports' into config/routes.rb. Use Rails::Generators::Base with source_root pointing to templates/.

**Test Strategy:**

Test generator creates all expected files. Test migration has correct schema. Test initializer has all config options. Test route injection.
