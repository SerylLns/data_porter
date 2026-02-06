---
title: "Building DataPorter #5 — Designing a Target DSL"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 5
tags: [ruby, rails, rails-engine, gem-development, dsl, metaprogramming, registry-pattern]
published: false
---

# Designing a Target DSL

> How to make each import type a single, self-describing Ruby class -- one file, zero boilerplate.

## Context

This is part 5 of the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 4](#), we modeled import records, errors, and reports using StoreModel and JSONB columns -- the data structures the engine operates on.

Now we need the layer that *describes* an import: what model does it target, what columns does it expect, how do CSV headers map to those columns? This is the Target DSL and the Registry that makes targets discoverable.

## The problem

Every import type in a Rails app needs the same boilerplate: column definitions, header mapping, validation rules, persistence logic. Without a convention, each import ends up in a different controller action or service object, with slightly different patterns. Adding a new import type means copying an existing one and changing field names.

We want a developer to open a single file, declare what their import looks like, and have the engine handle everything else. No initializer wiring, no registration callbacks, no controller configuration.

## What we're building

Here is what a complete target definition looks like in the host app:

```ruby
# app/data_porter/targets/guest_target.rb
class GuestTarget < DataPorter::Target
  label "Guests"
  model_name "Guest"
  icon "fas fa-users"
  sources :csv, :json

  columns do
    column :first_name, type: :string, required: true
    column :last_name,  type: :string, required: true
    column :email,      type: :email
  end

  csv_mapping do
    map "Prenom" => :first_name
    map "Nom"    => :last_name
  end

  deduplicate_by :email

  def persist(record, context:)
    Guest.create!(record.data)
  end
end
```

That is the entire file. The class-level DSL declares metadata and column schema. The instance method `persist` handles the actual write. The engine discovers this class through the Registry and wires it into the UI and orchestration layer automatically.

## Implementation

### Step 1 -- The Column struct

Before the Target itself, we need a value object for columns. Each column has a name, a type for validation, a required flag, a display label, and an open-ended options hash for type-specific settings like date formats.

```ruby
# lib/data_porter/dsl/column.rb
module DataPorter
  module DSL
    Column = Struct.new(:name, :type, :required, :label, :options, keyword_init: true) do
      def initialize(name:, type: :string, required: false, label: nil, **options)
        super(
          name: name.to_sym,
          type: type.to_sym,
          required: required,
          label: label || name.to_s.humanize,
          options: options
        )
      end
    end
  end
end
```

A `Struct` gives us equality, `to_h`, `members`, and frozen-by-value semantics for free. The constructor coerces `name` and `type` to symbols so callers can pass strings or symbols without worrying. The `label` falls back to `humanize` -- one less thing to type for the common case, but overridable when the generated label doesn't fit (`column :full_name, label: "Full Name"`). The `**options` splat captures anything else (like `format: "%d/%m/%Y"` for dates) and tucks it into the `options` hash, keeping the struct's interface stable as we add type-specific features.

### Step 2 -- The Target base class

The Target is where the DSL lives. All the declarative methods (`label`, `model_name`, `columns`, etc.) are class methods on a base class that host-app targets inherit from. Instance methods provide hook points for the import lifecycle.

```ruby
# lib/data_porter/target.rb
module DataPorter
  class Target
    class << self
      attr_reader :_label, :_model_name, :_icon, :_sources,
                  :_columns, :_csv_mappings, :_dedup_keys

      def label(value)      = @_label = value
      def model_name(value) = @_model_name = value
      def icon(value)       = @_icon = value

      def sources(*types)
        @_sources = types.map(&:to_sym)
      end

      def columns(&)
        @_columns = []
        instance_eval(&)
      end

      def column(name, **)
        @_columns << DSL::Column.new(name: name, **)
      end

      def csv_mapping(&)
        @_csv_mappings = {}
        instance_eval(&)
      end

      def map(hash)
        @_csv_mappings.merge!(hash)
      end

      def deduplicate_by(*keys)
        @_dedup_keys = keys.map(&:to_sym)
      end
    end
  end
end
```

Every DSL method is a class method that stores its value in a class instance variable (`@_label`, not `@@label`). The underscore prefix is a convention to signal "this is DSL storage, not your public API." The `columns` block uses `instance_eval` to execute `column` calls in the class context, which gives us the nested block syntax without requiring the caller to reference `self`.

The instance-level hooks provide the extensibility points for the import lifecycle:

```ruby
# lib/data_porter/target.rb (instance methods)
def transform(record)  = record
def validate(record)   = nil
def persist(_record, context:) = raise NotImplementedError
def after_import(_results, context:) = nil
def on_error(_record, _error, context:) = nil
```

`transform` and `validate` are no-ops by default -- override them if you need custom data munging or cross-field validation beyond type checking. `persist` raises `NotImplementedError` because every target must define how records get written. `after_import` and `on_error` are optional hooks for cleanup, notifications, or error recovery. The `context:` keyword argument carries the host app context (current user, tenant, etc.) that we set up in the configuration DSL back in part 3.

The split between class methods (declaration) and instance methods (execution) is deliberate. Class methods describe *what* the import is. Instance methods describe *what happens* during the import. The Orchestrator (part 7) will call `target_class._columns` to know the schema, then instantiate the target and call `target.persist(record, context: ctx)` for each row. Keeping these on different layers prevents the declaration phase from depending on runtime state.

### Step 3 -- The Registry

Targets need to be discoverable. The engine's UI shows a dropdown of available import types; the Orchestrator looks up a target by key to process an import. The Registry is the central index.

```ruby
# lib/data_porter/registry.rb
module DataPorter
  class TargetNotFound < Error; end

  module Registry
    @targets = {}

    class << self
      def register(key, klass)
        @targets[key.to_sym] = klass
      end

      def find(key)
        @targets.fetch(key.to_sym) do
          raise TargetNotFound, "Target '#{key}' not found"
        end
      end

      def available
        @targets.map do |key, klass|
          { key: key, label: klass._label, icon: klass._icon }
        end
      end

      def clear
        @targets = {}
      end
    end
  end
end
```

The Registry is a module with class-level state -- essentially a singleton hash. `register` adds a target class under a symbolic key. `find` retrieves it, raising a custom `TargetNotFound` error instead of a generic `KeyError` so the controller can rescue it with a proper 404. `available` returns lightweight summaries for the UI: just the key, label, and icon, without exposing the full class.

Registration happens in the host app's initializer:

```ruby
# config/initializers/data_porter.rb
DataPorter::Registry.register(:guests, GuestTarget)
DataPorter::Registry.register(:products, ProductTarget)
```

We considered auto-discovery (scanning a directory for Target subclasses), but explicit registration is simpler to reason about: you can see exactly which targets are active, control ordering, and conditionally register based on environment or feature flags. The `clear` and `refresh!` methods support testing and hot-reloading in development.

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| DSL placement | Class methods on a base class | Instance methods or a configuration hash | Class methods read like declarations, not procedure calls. They execute once at load time, not per-import |
| State storage | Class instance variables (`@_label`) | `class_attribute` from ActiveSupport | Class instance variables don't leak to subclasses by default, avoiding surprising inheritance behavior. We don't need the per-instance override that `class_attribute` provides |
| Column definition | `Struct` with keyword init | Plain hash or full ActiveModel class | Struct gives us typed attributes, equality, and `to_h` with no dependencies. A hash would lose the interface; ActiveModel would be overkill for a value object |
| Hook pattern | Instance methods with default no-ops | Event system or callback chain | Override-and-call is the simplest extension model. No subscription management, no ordering concerns. If you need it, override it |
| Registry | Explicit `register` calls | Auto-discovery via `inherited` hook or directory scanning | Explicit registration is visible, testable, and doesn't depend on load order or file system conventions. Auto-discovery can be added later as sugar on top |

## Testing it

Target specs verify both the DSL declarations and the default hook behavior:

```ruby
# spec/data_porter/target_spec.rb
let(:target_class) do
  Class.new(DataPorter::Target) do
    label "Guests"
    model_name "Guest"
    sources :csv, :json

    columns do
      column :first_name, type: :string, required: true
      column :email,      type: :email
    end

    csv_mapping do
      map "Prenom" => :first_name
    end
  end
end

it "sets the label" do
  expect(target_class._label).to eq("Guests")
end

it "defines columns" do
  expect(target_class._columns.size).to eq(2)
end

it "persist raises NotImplementedError" do
  expect { target_class.new.persist(nil, context: nil) }
    .to raise_error(NotImplementedError)
end
```

Registry specs confirm lookup, error handling, and the `available` summary:

```ruby
# spec/data_porter/registry_spec.rb
before { described_class.clear }

it "stores a target by key" do
  described_class.register(:guests, target_class)
  expect(described_class.find(:guests)).to eq(target_class)
end

it "raises TargetNotFound for unknown keys" do
  expect { described_class.find(:unknown) }
    .to raise_error(DataPorter::TargetNotFound)
end

it "returns target summaries" do
  described_class.register(:guests, target_class)
  result = described_class.available
  expect(result).to contain_exactly(
    { key: :guests, label: "Guests", icon: "fas fa-users" }
  )
end
```

Both suites run without a database. Anonymous classes (`Class.new(DataPorter::Target)`) let us define fresh targets per test without polluting the class hierarchy.

## Recap

- The **Target base class** uses class methods as a declarative DSL: `label`, `model_name`, `columns`, `csv_mapping`, and `deduplicate_by`. Each stores its value in a class instance variable, keeping subclasses isolated.
- The **Column struct** is a lightweight value object that captures name, type, required flag, display label, and open-ended options. Struct gives us equality and `to_h` for free.
- **Instance method hooks** (`transform`, `validate`, `persist`, `after_import`, `on_error`) separate runtime behavior from static declaration. Only `persist` is mandatory; the rest default to no-ops.
- The **Registry** is an explicit registration system that maps symbolic keys to target classes, providing lookup for the Orchestrator and summaries for the UI.

## Next up

We have data models (part 4) and a target DSL (this part) that describes what each import expects. In part 6, we will wire them together with the **Source layer** -- starting with CSV parsing, ActiveStorage file handling, and automatic column mapping from CSV headers to target columns. That is where the first end-to-end flow comes together: upload a file, parse it, and see structured records.

---

*This is part 5 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: Modeling import data with StoreModel & JSONB](#) | [Next: Parsing CSV data with Sources](#)*
