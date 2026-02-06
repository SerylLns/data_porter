# Task ID: 1

**Title:** Setup gem structure and Rails Engine

**Status:** pending

**Dependencies:** None

**Priority:** high

**Description:** Set up the core gem directory structure as defined in the spec (app/, lib/, config/, spec/) and configure the Rails Engine with isolate_namespace DataPorter. Include engine.rb with asset precompilation initializer, ActiveStorage initializer, and auto-discovery of target files from app/importers/.

**Details:**

Create the full directory tree: app/{channels,controllers,jobs,models,views}/data_porter/, lib/data_porter/{sources,store_models,dsl}/, config/, spec/. The Engine class should inherit from ::Rails::Engine, call isolate_namespace DataPorter, and set up initializers for assets, active_storage, and target auto-discovery via config.to_prepare. Update data_porter.gemspec with dependencies: rails (>= 7.0), store_model, phlex, turbo-rails, stimulus-rails. Update lib/data_porter.rb to require all sub-modules.

**Test Strategy:**

Verify the engine loads without errors. Test that isolate_namespace is correctly applied. Test that the initializer discovers target files.
