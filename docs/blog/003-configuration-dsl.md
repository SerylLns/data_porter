---
title: "Building DataPorter #3 — Configuration DSL: making the gem flexible"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 3
tags: [ruby, rails, rails-engine, gem-development, dsl, configuration, singleton-pattern]
published: false
---

# Configuration DSL: making the gem flexible

> A gem that can't adapt to its host app will never leave your own repo.

## Context

This is part 3 of the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 1](#), we established the problem and architecture. Part 2 covered scaffolding the engine gem with `isolate_namespace`.

In this article, we'll build the configuration layer: a clean DSL that lets host apps customize DataPorter's behavior through an initializer. By the end, you'll have a `DataPorter.configure` block that feels like any well-designed Rails gem.

## The problem

Our engine needs to run inside apps we don't control. One app uses Sidekiq with a custom queue name. Another stores files on S3. A third needs every import scoped to the current hotel's account.

Hard-coding any of these choices inside the gem would make it useless to anyone whose setup differs from ours. But making *everything* configurable turns the gem into a configuration puzzle where nobody remembers what goes where.

The challenge is finding the line between flexibility and convention -- and expressing it through an API that feels obvious on first read.

## What we're building

Here's the end result from the host app's perspective:

```ruby
# config/initializers/data_porter.rb
DataPorter.configure do |config|
  config.parent_controller = "Admin::BaseController"
  config.queue_name        = :low_priority
  config.storage_service   = :amazon
  config.preview_limit     = 200

  config.context_builder = ->(controller) {
    { hotel: controller.current_hotel, user: controller.current_user }
  }
end
```

This reads exactly like a Devise or Sidekiq initializer. A `configure` block yields a plain object with sensible defaults. If you don't call `configure` at all, everything still works.

## Implementation

### Step 1 -- The Configuration class

We need an object that holds every configurable value and provides reasonable defaults out of the box. The simplest approach that works: a plain Ruby class with `attr_accessor` and defaults set in `initialize`.

```ruby
# lib/data_porter/configuration.rb
module DataPorter
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
end
```

Every attribute has a default that makes the gem work without any initializer. `parent_controller` defaults to `"ApplicationController"` because that exists in every Rails app. `storage_service` defaults to `:local` because that requires zero setup. `preview_limit` caps at 500 rows to keep the preview page responsive.

Two attributes default to `nil` on purpose: `context_builder` and `scope`. These are opt-in features. When `context_builder` is nil, imports run without host-specific context. When `scope` is nil, the engine shows all imports. The gem checks for nil and adapts its behavior, rather than forcing a value that might be wrong.

Let's walk through the attributes that deserve a closer look.

**`parent_controller`** is a string, not a class. That's deliberate. At configuration time (during boot), the host app's controller class might not be loaded yet. We store the string and `constantize` it later, when Rails actually needs to resolve the inheritance chain.

**`context_builder`** is the most interesting one. It's a lambda that receives the current controller instance and returns whatever the host app needs during import. This is how a multi-tenant app passes `current_hotel` into the import flow without the gem knowing anything about hotels. We'll use this extensively when we build the Orchestrator in part 7.

**`enabled_sources`** lets the host app restrict which source types appear in the UI. If you only deal with CSV files, you can set `enabled_sources = %i[csv]` and the JSON/API options won't clutter the interface.

### Step 2 -- The module-level DSL

The Configuration class is just a data object. We need two module-level methods to turn it into a DSL: one to access the singleton instance, and one to yield it for configuration.

```ruby
# lib/data_porter.rb
module DataPorter
  class Error < StandardError; end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
```

`configuration` uses memoization via `||=` to ensure a single instance across the application. The first call creates a `Configuration.new` with all defaults; subsequent calls return the same object. This is the singleton pattern without the ceremony of the `Singleton` module.

`configure` yields that singleton to a block. Since `attr_accessor` creates both reader and writer methods, the block can set any attribute directly. After the block runs, `DataPorter.configuration.queue_name` returns whatever the host app set -- or the default if they didn't touch it.

There's no `reset!` method in production code. We don't need one. The configuration is set once during Rails boot and stays put for the process lifetime. We do need to reset between tests, but that's handled with `instance_variable_set` in the spec (we'll see that in a moment).

### Step 3 -- Wiring it up on boot

The configuration module gets required early, before the engine loads. This ensures `DataPorter.configure` is available when the host app's initializer runs.

```ruby
# lib/data_porter.rb (top of file)
require "rails/engine"
require_relative "data_porter/version"
require_relative "data_porter/configuration"
require_relative "data_porter/engine"
```

The load order matters. `configuration.rb` comes before `engine.rb` because the Engine class might reference configuration values during setup. In practice, Rails processes initializers after the engine is loaded, so the host app's `configure` block runs with the full gem already available.

Other parts of the gem read configuration like this:

```ruby
# Inside any DataPorter class
DataPorter.configuration.queue_name
DataPorter.configuration.context_builder&.call(controller)
```

The safe navigation operator (`&.`) on `context_builder` handles the nil default gracefully. When no builder is configured, the call simply returns nil instead of raising a NoMethodError.

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| Configuration object | Plain class with `attr_accessor` | `OpenStruct`, `Dry::Configurable` | No dependencies, easy to read, easy to document; IDE autocompletion works with real attributes |
| Singleton pattern | Memoized module instance variable | `Singleton` module, `Rails.application.config` | Simpler API (`DataPorter.configure`), no coupling to Rails config namespace, works in non-Rails test contexts |
| `context_builder` type | Lambda | Block stored as proc, method object | Lambdas enforce arity (catches wrong argument count), and the syntax `->() {}` signals "this is a callable" to the reader |
| `parent_controller` type | String | Class constant | Avoids load-order issues; the class may not exist at configuration time, but the string can be `constantize`d later |
| Default for optional features | `nil` | Null object pattern | Simpler to check `if context_builder` than to create a no-op null object; the gem has few enough optional features to keep the nil checks manageable |

## Testing it

The specs verify two things: that defaults are sane, and that the `configure` block actually mutates the singleton.

```ruby
# spec/data_porter/configuration_spec.rb
RSpec.describe DataPorter::Configuration do
  subject(:config) { described_class.new }

  it "has default parent_controller" do
    expect(config.parent_controller).to eq("ApplicationController")
  end

  it "has default queue_name" do
    expect(config.queue_name).to eq(:imports)
  end

  it "has default preview_limit" do
    expect(config.preview_limit).to eq(500)
  end

  it "has nil context_builder by default" do
    expect(config.context_builder).to be_nil
  end
end
```

Notice that each default gets its own test. This is intentional. When someone changes a default six months from now, the failure message says exactly which default broke, not just "configuration test failed."

The module-level specs test the singleton behavior and the `configure` yield pattern:

```ruby
# spec/data_porter/configuration_spec.rb
RSpec.describe DataPorter do
  describe ".configure" do
    after { DataPorter.instance_variable_set(:@configuration, nil) }

    it "yields the configuration" do
      DataPorter.configure do |config|
        config.queue_name = :custom_queue
      end

      expect(DataPorter.configuration.queue_name).to eq(:custom_queue)
    end
  end

  describe ".configuration" do
    after { DataPorter.instance_variable_set(:@configuration, nil) }

    it "memoizes the configuration" do
      expect(DataPorter.configuration).to be(DataPorter.configuration)
    end
  end
end
```

The `after` block resets the singleton between tests using `instance_variable_set`. This is the one place where we reach into internals, and it's acceptable because test isolation trumps encapsulation here. A public `reset!` method would leak test concerns into production code.

## Recap

- The `Configuration` class is a plain Ruby object with `attr_accessor` and defaults in `initialize`. No framework magic, no dependencies.
- Two module-level methods (`configure` and `configuration`) create the DSL that host apps use in their initializer.
- Sensible defaults mean the gem works with zero configuration. `context_builder` and `scope` are opt-in via nil defaults.
- Storing `parent_controller` as a string avoids boot-order issues. Using a lambda for `context_builder` enforces arity and reads clearly.

## Next up

Configuration tells the gem *how* to behave. In part 4, we'll tackle *what* it operates on: the data models. We'll use StoreModel and JSONB columns to store import records, validation errors, and summary reports as structured data inside a single table -- no migration per import type, no schema sprawl. If you've ever debated "extra table vs. JSON column," that's the one to read.

---

*This is part 3 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: Scaffolding a Rails Engine gem](#) | [Next: Modeling import data with StoreModel & JSONB](#)*
