---
title: "Building DataPorter #16 -- ERB View Templates: Composing Phlex Components"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 16
tags: [ruby, rails, rails-engine, gem-development, erb, phlex, views, active-storage, testing]
published: false
---

# ERB View Templates: Composing Phlex Components

> Phlex components are pure Ruby. ERB templates are what the browser actually sees. The glue between the two is a single method: `.call`.

## Context

This is part 16 of the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 9](#), we built seven Phlex components -- StatusBadge, SummaryCards, PreviewTable, ProgressBar, ResultsSummary, FailureAlert. In [part 10](#), we built the controller and routes. But we never connected the two.

The engine has a fully wired backend and a complete component library, but visiting `/imports` crashes with `ActionView::MissingTemplate`. The `app/views/data_porter/imports/` directory is empty. The controller sets instance variables, the components know how to render HTML, but there is no view template to orchestrate them.

In this article, we create three ERB templates -- index, new, and show -- that compose the existing Phlex components into full pages. We also fix a missing `has_one_attached :file` declaration, add a CSS stylesheet for all `dp-*` classes, and upgrade the test infrastructure to support view rendering in Rails 8.

## The missing attachment

Before touching views, there is a bug to fix. The CSV and JSON sources both call `@data_import.file.download`, but the DataImport model has no file attachment declared:

```ruby
# app/models/data_porter/data_import.rb
module DataPorter
  class DataImport < ActiveRecord::Base
    self.table_name = "data_porter_imports"

    has_one_attached :file

    belongs_to :user, polymorphic: true, optional: true
```

Two changes here. `has_one_attached :file` makes ActiveStorage available on the model. And `optional: true` on the `belongs_to` -- in Rails 5+, `belongs_to` associations are required by default. An engine should not enforce that constraint; the host app decides whether imports require a user.

Adding `has_one_attached` has a cascade effect on the test setup. ActiveStorage needs its tables (blobs, attachments, variant_records), a configured service, and a running Rails application to initialize the engine. Our previous spec_helper -- 15 lines of manual requires and an in-memory SQLite connection -- is not enough anymore.

## Upgrading the test infrastructure

The spec_helper needed a fundamental change: bootstrapping a real Rails application instead of manually requiring individual components.

```ruby
# spec/spec_helper.rb
ENV["RAILS_ENV"] = "test"

require "rails"
require "active_record"
require "active_job"
require "action_controller"
require "action_cable"
require "active_storage/engine"

module TestApp
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.active_storage.service = :test
    config.active_storage.service_configurations = {
      test: { service: "Disk", root: Dir.tmpdir }
    }
    config.active_job.queue_adapter = :test
    config.secret_key_base = "test_secret"
    config.root = File.expand_path("..", __dir__)
  end
end

require "data_porter"

Rails.application.initialize!

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
```

The key insight: `Rails.application.initialize!` must run *after* the connection is established, and *before* the schema is defined. ActiveStorage's engine hooks into the initialization process to register its models and set up the attachment macros. Without `initialize!`, `has_one_attached` raises `NoMethodError` because `ActiveStorage::Attached::Model` is never included into `ActiveRecord::Base`.

The schema definition gains three new tables for ActiveStorage:

```ruby
ActiveRecord::Schema.define do
  create_table :active_storage_blobs, force: true do |t|
    t.string   :key,          null: false
    t.string   :filename,     null: false
    t.string   :content_type
    t.text     :metadata
    t.string   :service_name, null: false
    t.bigint   :byte_size,    null: false
    t.string   :checksum
    t.datetime :created_at,   null: false
    t.index [:key], unique: true
  end

  create_table :active_storage_attachments, force: true do |t|
    t.string     :name,     null: false
    t.references :record,   null: false, polymorphic: true, index: false
    t.references :blob,     null: false
    t.datetime :created_at, null: false
    t.index %i[record_type record_id name blob_id],
            name: "index_active_storage_attachments_uniqueness",
            unique: true
  end

  create_table :active_storage_variant_records, force: true do |t|
    t.belongs_to :blob, null: false, index: false
    t.string :variation_digest, null: false
    t.index %i[blob_id variation_digest],
            name: "index_active_storage_variant_records_uniqueness",
            unique: true
  end
end
```

And we need a `User` stub and a `config/database.yml` for Rails to find during initialization:

```yaml
# config/database.yml
test:
  adapter: sqlite3
  database: ":memory:"
```

```ruby
# spec/spec_helper.rb (after schema)
class User < ActiveRecord::Base; end unless defined?(User)
```

The User model was previously not needed because without a full Rails app, the polymorphic `belongs_to` never tried to resolve the `User` constant. With `initialize!`, Rails activates the `belongs_to` presence validation, and any test that creates a `DataImport` with `user_type: "User"` triggers a `NameError`. The stub class fixes it cleanly.

One more piece: engine routes must be mounted in the test app *after* initialization:

```ruby
Rails.application.routes.draw do
  mount DataPorter::Engine, at: "/data_porter"
end
```

This is crucial for the view specs. Without it, the engine's URL helpers (`import_path`, `imports_path`) cannot resolve paths because the mount point is unknown.

## Rendering Phlex in ERB

DataPorter uses Phlex without `phlex-rails`. This means no `render` helper for Phlex components in ERB templates. Instead, we call `.call` directly, which returns an HTML string, and wrap it in `raw` to prevent double-escaping:

```erb
<%= raw DataPorter::Components::StatusBadge.new(status: @import.status).call %>
```

This is explicit and requires no gems, no monkey-patching, no initializer configuration. The tradeoff is that every component call is slightly verbose. But for a gem that ships views, this is a feature: the host app does not need to install phlex-rails, and there is no risk of version conflicts between the gem's Phlex setup and the host app's.

## The index template

The index page lists all imports with their status, target, source type, and creation date:

```erb
<%# app/views/data_porter/imports/index.html.erb %>
<div class="data-porter">
  <div class="dp-header">
    <h1 class="dp-title">Imports</h1>
    <%= link_to "New Import", new_import_path, class: "dp-btn dp-btn--primary" %>
  </div>

  <table class="dp-table">
    <thead>
      <tr>
        <th>ID</th>
        <th>Target</th>
        <th>Source</th>
        <th>Status</th>
        <th>Created</th>
        <th></th>
      </tr>
    </thead>
    <tbody>
      <% @imports.each do |import| %>
        <tr>
          <td><%= import.id %></td>
          <td><%= import.target_key %></td>
          <td><%= import.source_type %></td>
          <td><%= raw DataPorter::Components::StatusBadge.new(status: import.status).call %></td>
          <td><%= import.created_at&.strftime("%Y-%m-%d %H:%M") %></td>
          <td><%= link_to "View", import_path(import), class: "dp-link" %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

Each row includes a StatusBadge component rendered inline. The outer `<div class="data-porter">` scopes all styles. The URL helpers (`new_import_path`, `import_path`) are resolved through the engine's isolated namespace -- no `data_porter.` prefix needed inside engine views.

## The new import form

The form for creating an import uses `form_with` to build fields from the controller's instance variables:

```erb
<%# app/views/data_porter/imports/new.html.erb %>
<div class="data-porter">
  <h1 class="dp-title">New Import</h1>

  <%= form_with model: @import, url: imports_path, class: "dp-form" do |f| %>
    <div class="dp-field">
      <%= f.label :target_key, "Target", class: "dp-label" %>
      <%= f.select :target_key,
            @targets.map { |t| [t[:label], t[:key]] },
            { prompt: "Select a target..." },
            class: "dp-select" %>
    </div>

    <div class="dp-field">
      <%= f.label :source_type, "Source Type", class: "dp-label" %>
      <%= f.select :source_type,
            DataPorter.configuration.enabled_sources.map { |s| [s.to_s.upcase, s] },
            { prompt: "Select source type..." },
            class: "dp-select" %>
    </div>

    <div class="dp-field">
      <%= f.label :file, "File", class: "dp-label" %>
      <%= f.file_field :file, class: "dp-file-input" %>
    </div>

    <div class="dp-actions">
      <%= f.submit "Start Import", class: "dp-btn dp-btn--primary" %>
      <%= link_to "Cancel", imports_path, class: "dp-btn dp-btn--secondary" %>
    </div>
  <% end %>
</div>
```

The target select is populated from `@targets`, which comes from `DataPorter::Registry.available` -- an array of `{ key:, label:, icon: }` hashes built from the registered Target classes. The source type select reads from `DataPorter.configuration.enabled_sources`, defaulting to `[:csv, :json, :api]`.

The `url: imports_path` on `form_with` is necessary because the model is a `DataPorter::DataImport`, and Rails would try to generate a `data_porter_data_import_path` without the explicit URL. Inside engine views, explicit URLs for form actions avoid routing surprises.

## The show template: status-driven composition

The show page is where all the Phlex components come together. The key design: the template renders different components based on the import's current status:

```erb
<%# app/views/data_porter/imports/show.html.erb %>
<div class="data-porter">
  <div class="dp-header">
    <h1 class="dp-title">
      <%= @target._label %> Import #<%= @import.id %>
    </h1>
    <%= raw DataPorter::Components::StatusBadge.new(status: @import.status).call %>
  </div>

  <% if @import.parsing? || @import.importing? || @import.dry_running? %>
    <%= raw DataPorter::Components::ProgressBar.new(import_id: @import.id).call %>
  <% end %>

  <% if @import.previewing? %>
    <%= raw DataPorter::Components::SummaryCards.new(report: @import.report).call %>
    <%= raw DataPorter::Components::PreviewTable.new(
          columns: @target._columns,
          records: @records
        ).call %>

    <div class="dp-actions">
      <%= button_to "Confirm", confirm_import_path(@import),
            method: :post, class: "dp-btn dp-btn--primary" %>
      <% if @target._dry_run_enabled %>
        <%= button_to "Dry Run", dry_run_import_path(@import),
              method: :post, class: "dp-btn dp-btn--secondary" %>
      <% end %>
      <%= button_to "Cancel", cancel_import_path(@import),
            method: :post, class: "dp-btn dp-btn--danger" %>
    </div>
  <% end %>

  <% if @import.completed? %>
    <%= raw DataPorter::Components::ResultsSummary.new(report: @import.report).call %>
  <% end %>

  <% if @import.failed? %>
    <%= raw DataPorter::Components::FailureAlert.new(report: @import.report).call %>
    <div class="dp-actions">
      <%= button_to "Retry", parse_import_path(@import),
            method: :post, class: "dp-btn dp-btn--primary" %>
    </div>
  <% end %>
</div>
```

Five states, five rendering paths:

| Status | Components rendered |
|--------|-------------------|
| `parsing`, `importing`, `dry_running` | ProgressBar |
| `previewing` | SummaryCards + PreviewTable + action buttons |
| `completed` | ResultsSummary |
| `failed` | FailureAlert + Retry button |
| `pending` | Header only (waiting for job to start) |

The Dry Run button appears only when the target has enabled it (`@target._dry_run_enabled`). This is the DSL flag from part 14 surfacing in the UI -- targets opt in to dry run, and the view respects that choice without any extra configuration.

The action buttons use `button_to` which generates a mini-form with a POST request. This matches the route design from part 10: all member actions (confirm, cancel, dry_run, parse) are POST endpoints. No JavaScript needed for these actions -- they are standard form submissions that Turbo handles automatically.

## The CSS stylesheet

DataPorter ships a plain CSS file with styles for all `dp-*` classes. No build step, no Tailwind compilation, no PostCSS pipeline:

```css
/* app/assets/stylesheets/data_porter/application.css */
.data-porter {
  font-family: system-ui, -apple-system, sans-serif;
  color: #1a1a2e;
  max-width: 1200px;
  margin: 0 auto;
  padding: 1rem;
}

.dp-badge {
  display: inline-block;
  padding: 0.2rem 0.6rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
}

.dp-badge--pending { background: #e2e8f0; color: #475569; }
.dp-badge--completed { background: #d1fae5; color: #065f46; }
.dp-badge--failed { background: #fee2e2; color: #991b1b; }
/* ... one modifier per status */
```

Every class is scoped under `.data-porter` or prefixed with `dp-`. The host app's styles cannot accidentally override DataPorter's components, and DataPorter's styles cannot leak out. The full stylesheet covers tables, badges, cards, progress bars, forms, buttons, alerts, and results -- everything the components emit.

Host apps can override any of these styles. They can also ignore this stylesheet entirely and provide their own. The `dp-` prefix convention means they always have a clean selector to target.

## Testing views in a Rails 8 engine

Testing ERB templates in a Rails engine without a dummy app is not well documented. Rails 8 changed how `ActionView::Base` works -- you need `with_empty_template_cache` to create a usable view class, and the view needs both the engine's URL helpers and the main app's URL helpers to resolve paths correctly.

The solution lives in a shared helper:

```ruby
# spec/support/view_test_helper.rb
module ViewTestHelper
  VIEW_CLASS = ActionView::Base.with_empty_template_cache
  VIEW_CLASS.include DataPorter::Engine.routes.url_helpers
  VIEW_CLASS.include Rails.application.routes.url_helpers

  def build_view(assigns = {})
    lookup = ActionView::LookupContext.new(view_paths)
    ctrl = DataPorter::ImportsController.new
    ctrl.request = ActionDispatch::TestRequest.create
    ctrl.default_url_options = { host: "localhost" }

    view = VIEW_CLASS.new(lookup, assigns, ctrl)
    view.default_url_options = { host: "localhost" }
    view
  end

  def view_paths
    [File.expand_path("../../app/views", __dir__)]
  end
end
```

Three things are critical here:

**`ActionView::Base.with_empty_template_cache`** -- In Rails 8, `ActionView::Base.new` raises `NotImplementedError` asking for `compiled_method_container`. The `with_empty_template_cache` class method creates a subclass that has the right template caching setup.

**Both route helper modules** -- The engine's URL helpers (`import_path`, `imports_path`) resolve paths within the engine. The main app's URL helpers provide the mount point (`data_porter_path`) that the engine needs to construct full URLs. Without the main app helpers, named routes raise `NoMethodError: undefined method 'data_porter_path'`.

**`DataPorter::ImportsController.new` as the controller** -- The view delegates `_routes` resolution to its controller. Using `ActionController::Base.new` fails because it has no `_routes` for the engine namespace. Using the actual `ImportsController` -- which inherits the engine's route set -- makes all URL helpers work correctly.

The specs themselves are straightforward:

```ruby
RSpec.describe "data_porter/imports/show.html.erb" do
  include ViewTestHelper

  context "when previewing" do
    let(:status) { :previewing }

    it "renders the summary cards" do
      expect(html).to include("dp-summary-cards")
    end

    it "renders the preview table" do
      expect(html).to include("dp-preview-table")
    end

    it "shows confirm button" do
      expect(html).to include("Confirm")
    end
  end

  context "when failed" do
    it "renders the failure alert" do
      expect(html).to include("dp-alert")
    end

    it "shows retry button" do
      expect(html).to include("Retry")
    end
  end
end
```

Each context sets a different import status and verifies that the correct components and buttons are present. The assertions check for CSS class names (`dp-summary-cards`, `dp-alert`) rather than exact HTML structure, making them resilient to markup changes while still catching the important behavior: "this component is rendered for this status".

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| Phlex integration | `raw component.call` in ERB | phlex-rails gem with `render` helper | No extra dependency; explicit about what is happening; host app does not need phlex-rails installed |
| Template format | ERB wrappers composing Phlex | Pure Phlex page components | ERB is familiar to every Rails developer; forms and URL helpers work naturally; Phlex handles the complex rendering |
| Status-driven rendering | `if @import.parsing?` conditionals | Separate templates per status, Turbo Frame swapping | Simple, readable, works without JavaScript; one template to understand |
| CSS approach | Plain CSS file, no build step | Tailwind build, CSS-in-JS, Sass | Zero dependencies; host app can use any CSS pipeline; works out of the box |
| View test approach | `ActionView::Base.with_empty_template_cache` + engine controller | Dummy app, request specs, Capybara | Fast, no extra infrastructure; tests the template rendering directly |
| Form URL | Explicit `url: imports_path` | Let Rails infer from model | Avoids routing surprises with engine-namespaced models |

## Recap

- **`has_one_attached :file`** was missing from DataImport -- a bug that would crash CSV and JSON imports at runtime. Adding it required upgrading the test infrastructure to bootstrap a full Rails application with ActiveStorage.
- **ERB templates** compose Phlex components via `raw component.call` -- no phlex-rails dependency needed. The show template renders different components based on import status, making the page dynamic without JavaScript.
- **Plain CSS** with `dp-*` prefixed classes ships with the gem and works out of the box. Host apps can override or replace it entirely.
- **View testing in Rails 8** requires `ActionView::Base.with_empty_template_cache`, both engine and main app URL helpers, and the engine's own controller for proper route resolution. The `ViewTestHelper` encapsulates this setup in a reusable module.
- **22 view specs** cover all three templates and all status-driven rendering paths, running in under a second with no browser or dummy app.

## Next up

With the views in place, DataPorter is feature-complete. In the next and final article, we step back for a **showcase and retrospective** -- screenshots of the full workflow in a real app, a walkthrough from upload to import, and reflections on what the 16-article journey taught us about building Rails engines.

---

*This is part 16 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: Publishing & Retrospective](#) | [Next: Showcase & Final Retrospective](#)*
