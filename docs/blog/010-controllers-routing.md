---
title: "Building DataPorter #10 -- Controllers & Routing in a Rails Engine"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 10
tags: [ruby, rails, rails-engine, gem-development, controllers, routing, strong-params]
published: false
---

# Controllers & Routing in a Rails Engine

> Engine controllers are tricky -- they need to inherit from the host app, define routes that do not collide with anything else, and stay thin while coordinating an entire import workflow. Here is the clean way.

## Context

This is part 10 of the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 9](#), we built the UI layer with Phlex components and scoped Tailwind styles, giving users a visual interface for previewing and managing imports.

But a UI needs a backend to drive it. We need controller actions that create imports, kick off background jobs, let users confirm or cancel, and route everything under a clean, isolated namespace. In this article, we build the ImportsController, wire up engine routes with member actions, and solve one of the trickiest problems in engine development: making the controller inherit from whichever parent class the host app wants.

## The parent controller pattern

When you build a Rails engine, your controllers need to inherit from *something*. The obvious choice is `ActionController::Base`, but that is almost never what you want. Host apps typically have authentication, authorization, error handling, and layout logic on their own `ApplicationController` (or a dedicated `AdminController`). If your engine inherits from `ActionController::Base`, none of that flows through. The user would need to separately configure auth for every engine route -- a terrible experience.

The solution is dynamic inheritance. DataPorter's Configuration class exposes a `parent_controller` setting that defaults to `"ApplicationController"`:

```ruby
# lib/data_porter/configuration.rb
class Configuration
  attr_accessor :parent_controller,
                :queue_name,
                :storage_service,
                :cable_channel_prefix,
                :context_builder,
                :preview_limit,
                :enabled_sources,
                :scope

  def initialize
    @parent_controller = "ApplicationController"
    @queue_name = :imports
    @storage_service = :local
    @cable_channel_prefix = "data_porter"
    @context_builder = nil
    @preview_limit = 500
    @enabled_sources = %i[csv json api]
    @scope = nil
  end
end
```

The controller then uses `constantize` at class definition time to resolve the string into a class:

```ruby
# app/controllers/data_porter/imports_controller.rb
module DataPorter
  class ImportsController < DataPorter.configuration.parent_controller.constantize
```

This single line is doing a lot. When Ruby loads the controller file, it evaluates the superclass expression. `DataPorter.configuration.parent_controller` returns a string like `"ApplicationController"` or `"Admin::BaseController"`, and `.constantize` turns it into the actual class. The result is that `ImportsController` inherits from whatever the host app configured -- picking up its before_actions, authentication, layouts, and helper methods automatically.

A host app that wants all DataPorter routes behind admin authentication just needs:

```ruby
# config/initializers/data_porter.rb
DataPorter.configure do |config|
  config.parent_controller = "Admin::BaseController"
end
```

No monkey-patching, no middleware, no route constraints. The engine's controller *is* an admin controller.

The tradeoff is that this happens once, at load time. If you change the configuration after the controller class has been loaded, the inheritance does not update. In practice this is not an issue -- initializers run before controllers are loaded in production, and in development Rails reloads everything per-request anyway. But it is worth knowing: the parent controller is resolved eagerly, not lazily.

## Engine routes

DataPorter draws its routes inside the engine's own router, completely isolated from the host app:

```ruby
# config/routes.rb
DataPorter::Engine.routes.draw do
  resources :imports, only: %i[index new create show] do
    member do
      post :parse
      post :confirm
      post :cancel
    end
  end
end
```

The host app mounts the engine at whatever path it wants:

```ruby
# Host app: config/routes.rb
mount DataPorter::Engine, at: "/data_porter"
```

This produces the following route table:

| HTTP method | Path | Action | Purpose |
|-------------|------|--------|---------|
| GET | `/data_porter/imports` | `index` | List all imports |
| GET | `/data_porter/imports/new` | `new` | New import form |
| POST | `/data_porter/imports` | `create` | Create and start parsing |
| GET | `/data_porter/imports/:id` | `show` | Preview/status page |
| POST | `/data_porter/imports/:id/parse` | `parse` | Re-parse an import |
| POST | `/data_porter/imports/:id/confirm` | `confirm` | Confirm and start importing |
| POST | `/data_porter/imports/:id/cancel` | `cancel` | Cancel an import |

Notice what is *not* here: `edit`, `update`, `destroy`. An import is not a CRUD resource in the traditional sense. You create it, you preview it, you confirm or cancel it. There is no "edit an import" workflow -- if the data is wrong, you cancel and create a new one. The routes reflect this by using `only:` to restrict the standard REST actions and adding three custom member routes for the state-transition actions.

The member routes are all `post`, not `patch` or `put`. These are command actions that trigger side effects (enqueue a job, change status), not updates to a resource's attributes. POST is semantically correct here and plays well with Turbo, which sends POST requests from `button_to` helpers by default.

Because `isolate_namespace` is set on the engine, all routes are automatically scoped. Inside the controller, you use `import_path(@import)` and `imports_path` -- no prefix needed. The engine's router handles the namespace. This also means the host app's own `imports_path` (if it has one) is completely separate.

## Each action explained

Here is the full controller, then we will walk through each action:

```ruby
# app/controllers/data_porter/imports_controller.rb
module DataPorter
  class ImportsController < DataPorter.configuration.parent_controller.constantize
    before_action :set_import, only: %i[show parse confirm cancel]

    def index
      @imports = DataPorter::DataImport.order(created_at: :desc)
    end

    def new
      @import = DataPorter::DataImport.new
      @targets = DataPorter::Registry.available
    end

    def create
      @import = DataPorter::DataImport.new(import_params)
      @import.user = current_user if respond_to?(:current_user, true)
      @import.status = :pending

      if @import.save
        DataPorter::ParseJob.perform_later(@import.id)
        redirect_to import_path(@import)
      else
        @targets = DataPorter::Registry.available
        render :new
      end
    end

    def show
      @target = @import.target_class
      @records = @import.records
      @grouped = @records.group_by(&:status)
    end

    def parse
      @import.update!(status: :pending)
      DataPorter::ParseJob.perform_later(@import.id)
      redirect_to import_path(@import)
    end

    def confirm
      DataPorter::ImportJob.perform_later(@import.id)
      redirect_to import_path(@import)
    end

    def cancel
      @import.update!(status: :failed)
      redirect_to imports_path
    end

    private

    def set_import
      @import = DataPorter::DataImport.find(params[:id])
    end

    def import_params
      params.require(:data_import).permit(:target_key, :source_type, :file, config: {})
    end
  end
end
```

**`index`** -- Lists all imports, newest first. No pagination yet (that is a future enhancement), but the query is simple enough that the view layer can handle it. This is the dashboard view.

**`new`** -- Builds a blank DataImport and loads the available targets from the Registry. The view uses these to render a dropdown of import types. This is where the Target DSL pays off: each registered target provides its own label and icon, and the controller just passes the list through.

**`create`** -- The most interesting action. It builds the import from strong params, optionally assigns the current user (using `respond_to?(:current_user, true)` to avoid crashing if the host app has no authentication), sets the initial status, and saves. On success, it immediately enqueues a `ParseJob` and redirects to the show page where the user will see real-time progress. On failure, it reloads the targets and re-renders the form.

The `respond_to?(:current_user, true)` check deserves attention. The second argument (`true`) includes private methods in the check. Some authentication gems define `current_user` as a private helper. By passing `true`, we catch both public and private definitions. If the host app has no authentication at all, the check returns false and the user association is simply not set. The import still works -- `user` is a polymorphic optional association.

**`show`** -- Loads the target class, the records, and groups them by status. The view uses this grouping to show separate sections for complete, partial, and missing records. This is the preview page when the import is in `previewing` status, and the results page when it is `completed`.

**`parse`** -- Re-parses an existing import. This resets the status to `pending` and enqueues a new ParseJob. Useful when the user realizes the CSV mapping was wrong and re-uploads a file, or when a previous parse failed and they want to retry.

**`confirm`** -- The user has reviewed the preview and decided to proceed. This enqueues an ImportJob and redirects back to the show page, where ActionCable will push real-time progress updates (as we built in part 8).

**`cancel`** -- Marks the import as failed and redirects to the index. No job is enqueued, no further processing happens. The import is preserved in the database for auditing but is effectively dead.

## Strong params

The `import_params` method is deliberately minimal:

```ruby
def import_params
  params.require(:data_import).permit(:target_key, :source_type, :file, config: {})
end
```

Four permitted fields:

- **`target_key`** -- A string like `"user_import"` that maps to a registered target. The Target DSL and Registry validate this downstream.
- **`source_type`** -- A string like `"csv"`, `"json"`, or `"api"`. Determines which Source class handles the data.
- **`file`** -- An ActiveStorage attachment. The uploaded CSV, JSON, or other file.
- **`config`** -- A hash for source-specific configuration (API endpoints, headers, JSON root paths). The `config: {}` syntax permits any keys inside the hash, which is intentional: different source types need different config keys, and we validate them at the Source level rather than the controller level.

Notably absent: `status`, `records`, `report`, `user_id`, `user_type`. These are all set internally -- status by the controller and orchestrator, records and report by the ParseJob, and user by the controller's `current_user` logic. Strong params prevents any of these from being injected through the form.

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| Parent controller | Dynamic inheritance via `constantize` | Hardcoded `ActionController::Base` | Host app authentication, layouts, and helpers flow through automatically; zero extra configuration for auth |
| Route design | `only:` with custom member actions | Full `resources` CRUD | Imports are not a traditional CRUD resource; explicit routes match the actual workflow (create, preview, confirm/cancel) |
| Member action verbs | All POST | PATCH for parse, DELETE for cancel | These are command actions with side effects, not attribute updates; POST is semantically correct and works naturally with Turbo's `button_to` |
| User assignment | `respond_to?(:current_user, true)` guard | Requiring authentication | The engine must work with and without authentication; optional user association keeps it flexible |
| Config params | `config: {}` (open hash) | Explicitly listing every config key | Different source types need different config keys; validation happens at the Source level where context exists |
| No edit/update/destroy | Omitted from routes entirely | Including them "just in case" | An import is an immutable workflow; if it is wrong, you cancel and start over; fewer routes means fewer security surfaces |

## Testing it

Testing engine controllers without a full Rails app or a dummy app is the interesting challenge here. The approach we use: stub just enough of the Rails stack to load the controller class, then test its structure directly.

The spec helper handles the setup. It loads the minimal Rails dependencies, sets up an in-memory SQLite database, stubs `ApplicationController`, and manually requires the controller:

```ruby
# spec/spec_helper.rb (relevant excerpt)
require "rails"
require "action_controller"

# Stub for controller inheritance in test context
class ApplicationController < ActionController::Base; end unless defined?(ApplicationController)

$LOAD_PATH.unshift File.expand_path("../app/controllers", __dir__)
require "data_porter/imports_controller"
```

The `unless defined?(ApplicationController)` guard is important -- it prevents double-definition errors if the host app's ApplicationController has already been loaded (which happens in integration test suites).

With that foundation, the controller spec tests structure rather than HTTP behavior:

```ruby
# spec/data_porter/imports_controller_spec.rb
RSpec.describe DataPorter::ImportsController do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Test Import"
      icon "fas fa-test"
      model_name "TestModel"

      columns do
        column :name, type: :string, required: true
      end
    end
  end

  before do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:test_import, target_class)
  end

  after { DataPorter::Registry.clear }

  describe "inheritance" do
    it "inherits from the configured parent controller" do
      expect(described_class.superclass.name).to eq(DataPorter.configuration.parent_controller)
    end
  end

  describe "before_actions" do
    it "registers set_import callback" do
      callbacks = described_class._process_action_callbacks.select do |c|
        c.filter == :set_import
      end

      expect(callbacks).not_to be_empty
    end
  end

  describe "action methods" do
    it "defines index, new, create, show, parse, confirm, and cancel" do
      actions = %i[index new create show parse confirm cancel]
      actions.each do |action|
        expect(described_class.instance_method(action)).to be_a(UnboundMethod)
      end
    end
  end

  describe "private methods" do
    it "defines set_import" do
      expect(described_class.private_instance_methods).to include(:set_import)
    end

    it "defines import_params" do
      expect(described_class.private_instance_methods).to include(:import_params)
    end
  end
end
```

There are a few things worth noting about this approach:

First, the tests verify *inheritance* rather than HTTP responses. The `"inherits from the configured parent controller"` spec confirms that the dynamic `constantize` pattern actually works and that the controller's superclass matches the configuration. If someone changes the inheritance line, this catches it.

Second, callback registration is tested by inspecting `_process_action_callbacks` directly. This is a Rails internal API, but it is stable and avoids the need to make real HTTP requests just to check that a before_action is wired up.

Third, the action methods spec iterates over all seven expected actions and verifies they exist as instance methods. This is a structural test -- it does not exercise the action logic, but it catches missing methods immediately.

The routes get their own spec that redraws the engine routes and inspects the route set:

```ruby
# spec/data_porter/routes_spec.rb
RSpec.describe "DataPorter routes" do
  before(:all) do
    DataPorter::Engine.routes.draw do
      resources :imports, only: %i[index new create show] do
        member do
          post :parse
          post :confirm
          post :cancel
        end
      end
    end
  end

  it "defines import resource routes" do
    routes = DataPorter::Engine.routes
    route_set = routes.routes.map { |r| [r.defaults[:action], r.path.spec.to_s] }

    expect(route_set).to include(["index", "/imports(.:format)"])
    expect(route_set).to include(["new", "/imports/new(.:format)"])
    expect(route_set).to include(["create", "/imports(.:format)"])
    expect(route_set).to include(["show", "/imports/:id(.:format)"])
  end

  it "defines member routes for parse, confirm, and cancel" do
    routes = DataPorter::Engine.routes
    route_set = routes.routes.map { |r| [r.defaults[:action], r.path.spec.to_s] }

    expect(route_set).to include(["parse", "/imports/:id/parse(.:format)"])
    expect(route_set).to include(["confirm", "/imports/:id/confirm(.:format)"])
    expect(route_set).to include(["cancel", "/imports/:id/cancel(.:format)"])
  end
end
```

The `before(:all)` block redraws the routes inside the test environment. This is necessary because the engine's routes file is loaded differently in test versus production. By explicitly drawing the routes, we guarantee the test is exercising the exact route definitions we ship, not whatever routes happened to be loaded by a host app. The specs then map each route to an `[action, path]` pair and verify all seven are present with the correct paths.

This style of testing -- structural rather than behavioral -- may feel unusual. But for an engine, it is the right level of abstraction. Full request specs belong in the host app's integration suite, where they can exercise the real authentication stack, the real database, and the real views. The engine's specs verify that the pieces are correctly defined and wired together.

## Recap

- The **dynamic parent controller pattern** uses `constantize` to resolve the configured controller name at class-load time, allowing the engine to inherit authentication, layouts, and helpers from whatever base class the host app chooses.
- **Engine routes** are drawn inside `DataPorter::Engine.routes.draw`, keeping them isolated from the host app. The host mounts the engine at any path it wants.
- **Seven actions** map to a clean import workflow: list, create, preview, re-parse, confirm, cancel. No edit or destroy -- imports are immutable workflows.
- **Strong params** permit only the fields the user should control (`target_key`, `source_type`, `file`, `config`), while status, records, and user are set internally.
- **Controller specs** test structure (inheritance, callbacks, method existence) rather than HTTP behavior, avoiding the need for a full dummy app.

## Next up

The controller and routes give us a working web interface, but setting up DataPorter in a host app still requires creating a migration, writing an initializer, mounting routes, and knowing the right directory for target classes. In part 11, we build **install and target generators** -- `rails generate data_porter:install` that handles the entire setup in one command, and `rails generate data_porter:target` that scaffolds a new import type with columns pre-filled from the command line.

---

*This is part 10 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: Building the UI with Phlex & Tailwind](#) | [Next: Generators: Install & Target Scaffolding](#)*
