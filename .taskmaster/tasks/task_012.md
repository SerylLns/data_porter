# Task ID: 12

**Title:** Build ImportsController with all actions

**Status:** pending

**Dependencies:** 7, 10

**Priority:** high

**Description:** Implement DataPorter::ImportsController inheriting from configured parent_controller. Actions: index, new, create, show, parse, confirm, cancel. Wire up routes.

**Details:**

Create app/controllers/data_porter/imports_controller.rb inheriting from DataPorter.configuration.parent_controller.constantize. before_action :set_import for show/parse/confirm/cancel. index: list imports ordered by created_at desc. new: build new DataImport, load available targets. create: build DataImport from params, assign current_user, enqueue ParseJob on save. show: load target, records, grouped records. parse: reset to pending and re-enqueue ParseJob. confirm: enqueue ImportJob. cancel: set status to failed. Create config/routes.rb with DataPorter::Engine.routes.draw: resources :imports with member routes for parse, confirm, cancel.

**Test Strategy:**

Test each controller action. Test strong params. Test job enqueuing on create and confirm. Test status transitions on parse and cancel.
