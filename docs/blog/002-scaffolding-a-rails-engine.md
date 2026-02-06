---
title: "Building DataPorter #2 — Scaffolding a Rails Engine gem"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 2
tags: [ruby, rails, rails-engine, gem-development, architecture]
published: false
---

# Scaffolding a Rails Engine gem

> Running `bundle gem` is just the beginning. Here's how to turn a blank gem into a proper Rails Engine with isolated namespacing, auto-loading, and a clean dependency story.

## Context

In [Part 1](/docs/blog/001-why-build-a-data-import-engine.md), we defined the problem DataPorter solves: a reusable, multi-step import workflow for Rails apps. We talked about architecture, the tech stack, and what sets this gem apart from existing solutions.

Now it's time to write code. In this article, we'll scaffold the gem, wire up the Rails Engine, and make our first real decisions about directory structure, namespacing, and dependencies.

## The problem

`bundle gem data_porter` gives you a perfectly valid Ruby gem. But it gives you a Ruby gem, not a Rails Engine. There's no `config/routes.rb`, no autoloading of models or controllers, no way for a host app to mount your gem at a path. A raw gem doesn't know anything about Rails.

Turning that skeleton into a mountable engine means answering a few questions upfront: How do we isolate our namespace so we don't collide with the host app? How do we structure directories so Rails autoloading works inside the gem? Which dependencies do we declare, and how tightly do we pin them?

Get these wrong and you'll be fighting Rails conventions for the rest of the project. Get them right and everything else just works.

## What we're building

By the end of this article, the gem will have a working Engine, an isolated namespace, auto-discovery of host app import targets, and a clean gemspec. Here's the directory tree we're aiming for:

```
data_porter/
  config/
    routes.rb               # Engine routes (empty for now)
  lib/
    data_porter.rb           # Entry point: requires + module-level API
    data_porter/
      version.rb             # Version constant
      engine.rb              # The Rails Engine
      configuration.rb       # Config object (teased here, detailed in Part 3)
  spec/
    data_porter/
      engine_spec.rb         # Engine specs
  data_porter.gemspec        # Dependencies and metadata
```

This is deliberately minimal. We'll add `app/models`, `app/controllers`, and `app/views` directories as we build those layers in later articles. Rails Engine autoloading picks them up automatically once they exist, so there's no reason to create empty folders now.

## Implementation

### Step 1 -- The Engine class

The Engine is the single most important file in a Rails Engine gem. It's the bridge between your gem and the host application's Rails stack.

```ruby
# lib/data_porter/engine.rb
module DataPorter
  class Engine < ::Rails::Engine
    isolate_namespace DataPorter

    config.to_prepare do
      Dir[Rails.root.join("app/importers/*_target.rb")].each { |f| require f }
    end
  end
end
```

Three things happen in these few lines, and each one matters.

First, we inherit from `::Rails::Engine`. The leading `::` ensures we reference the top-level `Rails` module, not anything that might be nested under `DataPorter`. This is the line that tells Rails "this gem provides engine functionality" -- routes, autoloading, migrations, the works.

Second, `isolate_namespace DataPorter` is the key architectural decision. It tells Rails to scope everything the engine provides -- routes, models, controllers -- under the `DataPorter` module. Without it, a `DataImport` model in the engine would collide with a `DataImport` model in the host app. Isolation means our table names become `data_porter_data_imports`, our routes get prefixed, and the host app stays clean.

Third, the `config.to_prepare` block handles auto-discovery. We want host apps to define import targets in `app/importers/` using a simple naming convention: `*_target.rb`. The `to_prepare` callback runs before each request in development (so changes are picked up without a restart) and once at boot in production. This is the standard Rails pattern for loading code that needs to exist before the app serves requests.

### Step 2 -- The entry point

Every gem needs a single file that bootstraps everything. Ours is `lib/data_porter.rb`, and it sets the order of operations.

```ruby
# lib/data_porter.rb
require "rails/engine"
require_relative "data_porter/version"
require_relative "data_porter/configuration"
require_relative "data_porter/engine"

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

The require order is intentional. We load `rails/engine` first because `DataPorter::Engine` inherits from it. Then the version (needed by the gemspec), then configuration (needed by the module-level API), then the engine itself.

The `DataPorter` module also defines the gem's public API surface. `DataPorter.configure` with a block is the pattern host apps will use to customize behavior. `DataPorter::Error` gives us a base exception class to inherit from in later parts. We'll dive deep into the configuration DSL in Part 3 -- for now, the important thing is that the scaffolding is in place.

Notice that we use `require_relative` for our own files and `require` for external dependencies. This is a minor but useful convention: `require_relative` is resolved from the current file's location, so it works regardless of how the gem is loaded. `require` goes through the Ruby load path, which is correct for third-party gems.

### Step 3 -- The gemspec

The gemspec declares what the gem needs to run and how it should be packaged. Let's look at the dependency section, which is where the real decisions live.

```ruby
# data_porter.gemspec
Gem::Specification.new do |spec|
  spec.name = "data_porter"
  spec.version = DataPorter::VERSION
  spec.required_ruby_version = ">= 3.2.0"

  # ...metadata...

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "store_model", ">= 2.0"
  spec.add_dependency "phlex", ">= 1.0"
  spec.add_dependency "turbo-rails", ">= 1.0"
end
```

Four runtime dependencies, each chosen for a specific reason.

**rails >= 7.0** is the floor. We use features like `enum` improvements and `config.to_prepare` patterns that are stable from Rails 7 onward. No upper bound -- we trust semver and test against multiple Rails versions in CI.

**store_model >= 2.0** lets us define typed, validatable Ruby objects backed by JSONB columns. We'll use it to model import records, errors, and reports without creating extra database tables. Part 4 covers this in detail.

**phlex >= 1.0** gives us Ruby-native view components. We chose it over ViewComponent because Phlex components are plain Ruby classes -- easier to namespace, easier to test, no template files to manage inside a gem.

**turbo-rails >= 1.0** provides Turbo Frames and Turbo Streams. The import workflow is a natural fit for Turbo: upload in one frame, preview in another, progress updates via streams.

All version constraints use `>=` with a floor, not `~>` with a pessimistic lock. This is deliberate for a library gem. A host app should control the exact versions through its `Gemfile.lock`. If we locked `phlex ~> 1.0`, we'd block any host app that wants to use Phlex 2.x. The trade-off is that we need CI coverage across versions, but that's a solvable problem (and we'll set that up in a later article).

Also worth noting: the `files` array in the gemspec uses `git ls-files` and explicitly excludes test files, bin scripts, and CI config. The published gem should only include what's needed to run it.

## Decisions and tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| Namespace isolation | `isolate_namespace` | Full engine (no isolation) | Prevents model/route collisions with host app |
| Version constraints | `>= floor` (optimistic) | `~> x.y` (pessimistic) | Library gems should not lock transitive dependencies tightly |
| Target auto-discovery | `config.to_prepare` with Dir glob | Explicit registration API | Convention over configuration; zero boilerplate for host apps |
| View layer | Phlex | ERB / ViewComponent | Pure Ruby classes are easier to namespace and test inside a gem |
| Require strategy | `require_relative` for internal files | `require` for everything | Resolves from file location, works regardless of load path state |

## Testing it

We can verify the engine is wired up correctly with a focused spec.

```ruby
# spec/data_porter/engine_spec.rb
RSpec.describe DataPorter::Engine do
  it "is a Rails::Engine" do
    expect(described_class.superclass).to eq(Rails::Engine)
  end

  it "has an isolated namespace" do
    expect(described_class.isolated?).to be true
  end

  it "is namespaced under DataPorter" do
    expect(described_class.engine_name).to eq("data_porter")
  end
end
```

These three assertions confirm the fundamentals: the class hierarchy is correct, isolation is active, and the engine name Rails derives matches what we expect. The `isolated?` check is particularly important -- if someone accidentally removes the `isolate_namespace` line, this test catches it immediately.

## Recap

- A Rails Engine is what turns a Ruby gem into something a Rails app can mount, with routes, autoloading, and migrations.
- `isolate_namespace` prevents name collisions between the engine and the host app. It's a one-liner, but it shapes the entire architecture.
- The entry point (`lib/data_porter.rb`) sets up the require order and defines the gem's public API surface.
- Gemspec dependencies should use optimistic version constraints (`>=`) so host apps stay in control of their dependency tree.
- The `config.to_prepare` callback gives us zero-config auto-discovery of import targets in the host app.

## Next up

We have a working engine, but it's not configurable yet. In Part 3, we'll build the configuration DSL -- the `DataPorter.configure` block that lets host apps customize parent controllers, queue names, storage backends, and more. We'll look at why a dedicated configuration object beats scattering settings across `Rails.application.config`, and how to design defaults that make sense out of the box.

---

*This is part 2 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: Why build a data import engine?](/docs/blog/001-why-build-a-data-import-engine.md) | [Next: Configuration DSL](#)*
*Code: [GitHub](https://github.com/SerylLns/data_porter)*
