---
title: "Building DataPorter #11 -- Generators: Install & Target Scaffolding"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 11
tags: [ruby, rails, rails-engine, gem-development, generators, scaffolding, templates]
published: false
---

# Generators: Install & Target Scaffolding

> A great gem installs in one command. A great engine scaffolds new import types from the command line. Here is how to build Rails generators that bootstrap everything -- migration, initializer, routes, and per-target files -- so adopters never have to wire anything by hand.

## Context

This is part 11 of the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 10](#), we built the ImportsController, wired up engine routes, and solved the dynamic parent controller inheritance problem.

At this point the engine is feature-complete: targets, sources, the orchestrator, real-time progress, a Phlex UI, and controllers all work together. But onboarding a new host app still requires manually creating a migration, writing an initializer, mounting the engine in routes, and knowing the exact Target DSL to define an import type. That is too many steps for someone evaluating the gem for the first time. We need generators that collapse all of that into a single `rails generate` command.

## The problem

Installing a Rails engine by hand means at least four discrete steps: copy a migration, create an initializer with sane defaults, add a route mount, and create the directory where import targets will live. Miss any one of these and the engine will not work -- but the error messages will not tell you which step you forgot. A missing migration produces an `ActiveRecord::StatementInvalid`; a missing route mount means a `NoMethodError` when the engine tries to resolve its URL helpers; a missing initializer silently uses defaults that may not match your app.

On top of that, every time a developer wants to add a new import type, they need to remember the Target DSL: which class to inherit from, which methods to define, how to declare columns. That is cognitive overhead that belongs in a generator, not in someone's memory.

## What we are building

Two generators. The first bootstraps the entire engine into a host app:

```bash
$ rails generate data_porter:install
      create  db/migrate/20260206120000_create_data_porter_imports.rb
      create  config/initializers/data_porter.rb
      create  app/importers
       route  mount DataPorter::Engine, at: "/imports"
```

The second scaffolds a new target with parsed column definitions:

```bash
$ rails generate data_porter:target guests first_name:string:required email:email last_name:string
      create  app/importers/guests_target.rb
```

One command to install, one command per import type. No manual file creation, no DSL memorization.

## Implementation

### Step 1 -- The install generator

The install generator inherits from `Rails::Generators::Base` and mixes in `ActiveRecord::Generators::Migration` for timestamped migration support. Each public method in the generator becomes a step that Rails executes in definition order:

```ruby
# lib/generators/data_porter/install/install_generator.rb
module DataPorter
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def copy_migration
        migration_template(
          "create_data_porter_imports.rb.erb",
          "db/migrate/create_data_porter_imports.rb"
        )
      end

      def copy_initializer
        template("initializer.rb", "config/initializers/data_porter.rb")
      end

      def create_importers_directory
        empty_directory("app/importers")
      end

      def mount_engine
        route 'mount DataPorter::Engine, at: "/imports"'
      end
    end
  end
end
```

Four methods, four artifacts. Let us walk through each one.

`copy_migration` uses `migration_template` instead of the plain `template` method. The difference matters: `migration_template` adds a timestamp prefix to the filename and raises an error if a migration with the same name already exists, preventing duplicate migrations when someone accidentally runs the generator twice. The template itself is an ERB file that interpolates the current ActiveRecord migration version:

```ruby
# lib/generators/data_porter/install/templates/create_data_porter_imports.rb.erb
class CreateDataPorterImports < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :data_porter_imports do |t|
      t.string  :target_key,  null: false
      t.string  :source_type, null: false, default: "csv"
      t.integer :status,      null: false, default: 0
      t.jsonb   :records,     null: false, default: []
      t.jsonb   :report,      null: false, default: {}
      t.jsonb   :config,      null: false, default: {}

      t.references :user, polymorphic: true, null: false

      t.timestamps
    end

    add_index :data_porter_imports, :status
    add_index :data_porter_imports, :target_key
  end
end
```

The `<%= ActiveRecord::Migration.current_version %>` call means the generated migration always matches the host app's Rails version -- a Rails 7.1 app gets `Migration[7.1]`, a Rails 7.2 app gets `Migration[7.2]`. No hardcoding, no compatibility issues.

`copy_initializer` generates a commented-out configuration file. Every option is present but disabled, so developers can see what is available without digging through source code:

```ruby
# lib/generators/data_porter/install/templates/initializer.rb
DataPorter.configure do |config|
  # Parent controller for the engine's controllers to inherit from.
  # This controls authentication, layouts, and helpers.
  # config.parent_controller = "ApplicationController"

  # ActiveJob queue name for import jobs.
  # config.queue_name = :imports

  # ActiveStorage service for uploaded files.
  # config.storage_service = :local

  # ActionCable channel prefix.
  # config.cable_channel_prefix = "data_porter"

  # Context builder: inject business data into targets.
  # Receives the current controller instance.
  # config.context_builder = ->(controller) {
  #   OpenStruct.new(
  #     user: controller.current_user
  #   )
  # }

  # Maximum number of records displayed in preview.
  # config.preview_limit = 500

  # Enabled source types.
  # config.enabled_sources = %i[csv json api]
end
```

This is a deliberate design choice: every option documents itself with a comment that explains *what it controls*, not just what it is. The `context_builder` lambda even includes a usage example. When someone opens this file for the first time, they should understand the engine's configuration surface without reading the README.

`create_importers_directory` calls `empty_directory`, which creates `app/importers` and silently skips if it already exists. This is where host apps will place their target files.

`mount_engine` uses the built-in `route` helper, which injects the mount line into `config/routes.rb`. The default mount point is `/imports`, but because it is a standard route mount, developers can change the path or wrap it in constraints after generation.

### Step 2 -- The target generator

The target generator inherits from `Rails::Generators::NamedBase` instead of `Base`. This gives us the `name` argument for free -- Rails automatically parses the first argument as the target name and provides helper methods like `class_name`, `file_name`, and `singular_name`:

```ruby
# lib/generators/data_porter/target/target_generator.rb
module DataPorter
  module Generators
    class TargetGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :columns, type: :array, default: [], banner: "name:type[:required]"

      def create_target_file
        template("target.rb.tt", "app/importers/#{file_name}_target.rb")
      end

      private

      def target_class_name
        "#{class_name}Target"
      end

      def model_name
        class_name.singularize
      end

      def target_label
        class_name.titleize
      end

      def parsed_columns
        columns.map { |col| parse_column(col) }
      end

      def parse_column(definition)
        parts = definition.split(":")
        {
          name: parts[0],
          type: parts[1] || "string",
          required: parts[2] == "required"
        }
      end
    end
  end
end
```

The `columns` argument uses `type: :array` with a `default: []`, which means you can generate a bare target with no columns and fill them in later, or you can specify everything up front. The `banner` string `"name:type[:required]"` tells `rails generate data_porter:target --help` exactly what format columns expect.

The `parse_column` method splits each column definition on colons. `first_name:string:required` becomes `{ name: "first_name", type: "string", required: true }`. `email:email` becomes `{ name: "email", type: "email", required: false }`. If you omit the type entirely, it defaults to `"string"`. This mirrors the familiar `rails generate model` syntax but adapts it to our column DSL.

The naming helpers derive everything from the single `name` argument. Pass `guests` and you get: `target_class_name` returns `"GuestsTarget"`, `model_name` returns `"Guest"` (singularized, because the target usually maps to one ActiveRecord model), and `target_label` returns `"Guests"` (titleized, for the UI).

### Step 3 -- The target template

The template uses Thor's `.tt` format (which processes ERB tags using the generator's binding) to produce a complete, working target file:

```erb
# lib/generators/data_porter/target/templates/target.rb.tt
class <%= target_class_name %> < DataPorter::Target
  label "<%= target_label %>"
  model_name "<%= model_name %>"
  icon "fas fa-file-import"
  sources :csv
<% if parsed_columns.any? %>

  columns do
<% parsed_columns.each do |col| -%>
    column :<%= col[:name] %>, type: :<%= col[:type] %><%= ", required: true" if col[:required] %>
<% end -%>
  end
<% end %>

  def persist(record, context:)
    # <%= model_name %>.create!(record.attributes)
  end
end
```

Running `rails generate data_porter:target guests first_name:string:required email:email last_name:string` produces:

```ruby
# app/importers/guests_target.rb
class GuestsTarget < DataPorter::Target
  label "Guests"
  model_name "Guest"
  icon "fas fa-file-import"
  sources :csv

  columns do
    column :first_name, type: :string, required: true
    column :email, type: :email
    column :last_name, type: :string
  end

  def persist(record, context:)
    # Guest.create!(record.attributes)
  end
end
```

Two details worth noting. First, the `persist` method is generated with a commented-out implementation line. This is intentional: we want the developer to think about what persistence means for their domain rather than blindly accepting a default. Maybe they need `find_or_create_by`, maybe they need to call a service object, maybe they need to update existing records. The commented hint shows the simplest path while making it clear this is the one method they *must* customize.

Second, the `columns` block is conditionally rendered. If you run `rails generate data_porter:target guests` with no columns, you get a clean skeleton without an empty `columns do; end` block. You can add columns later as you figure out your CSV structure.

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| Generator base class | `NamedBase` for target, `Base` for install | Both using `Base` | `NamedBase` gives us `class_name`, `file_name`, and argument parsing for free; install does not need a name argument |
| Migration template format | ERB (`.rb.erb`) with `ActiveRecord::Migration.current_version` | Hardcoded migration version | The generated migration automatically matches the host app's Rails version |
| Column parsing syntax | `name:type[:required]` colon-separated | A flag-based approach (`--columns name:string --required name`) | Matches the familiar `rails generate model` convention; less typing, easier to remember |
| Initializer style | All options commented out with explanations | Only showing uncommented defaults | Developers discover every configuration option on first read; uncommenting is easier than looking up what is available |
| Target output directory | `app/importers/` | `app/data_porter/targets/` or `app/models/concerns/` | Short, clear, conventional; mirrors how apps organize service objects in `app/services/` |
| Persist method | Commented-out hint (`# Guest.create!(...)`) | Working default implementation | Forces the developer to make an intentional choice about their persistence strategy |

## Testing it

Generator testing is unusual -- you are testing that files get created with the right content, not that objects behave correctly. The specs verify the generator's structure and its column-parsing logic without actually running the generator against a filesystem:

```ruby
# spec/data_porter/generators/install_generator_spec.rb
RSpec.describe DataPorter::Generators::InstallGenerator do
  it "inherits from Rails::Generators::Base" do
    expect(described_class.superclass).to eq(Rails::Generators::Base)
  end

  it "has a source_root pointing to templates" do
    expect(described_class.source_root).to end_with("lib/generators/data_porter/install/templates")
  end

  describe "generator methods" do
    it "defines copy_migration" do
      expect(described_class.instance_method(:copy_migration)).to be_a(UnboundMethod)
    end

    it "defines copy_initializer" do
      expect(described_class.instance_method(:copy_initializer)).to be_a(UnboundMethod)
    end

    it "defines create_importers_directory" do
      expect(described_class.instance_method(:create_importers_directory)).to be_a(UnboundMethod)
    end

    it "defines mount_engine" do
      expect(described_class.instance_method(:mount_engine)).to be_a(UnboundMethod)
    end
  end
end
```

The install generator specs verify that the class inherits from the right base, that the source root points to the templates directory, and that each expected method exists. This is a structural test: if someone renames a method or changes the inheritance chain, the spec catches it immediately.

The target generator specs go deeper, testing the column parsing and naming derivation:

```ruby
# spec/data_porter/generators/target_generator_spec.rb
RSpec.describe DataPorter::Generators::TargetGenerator do
  it "inherits from Rails::Generators::NamedBase" do
    expect(described_class.superclass).to eq(Rails::Generators::NamedBase)
  end

  describe "column parsing" do
    let(:generator) { described_class.new(["guests", "first_name:string:required", "email:email"]) }

    it "parses column definitions" do
      columns = generator.send(:parsed_columns)

      expect(columns.size).to eq(2)
      expect(columns[0]).to eq({ name: "first_name", type: "string", required: true })
      expect(columns[1]).to eq({ name: "email", type: "email", required: false })
    end
  end

  describe "naming" do
    let(:generator) { described_class.new(["guests"]) }

    it "derives the class name" do
      expect(generator.send(:target_class_name)).to eq("GuestsTarget")
    end

    it "derives the model name" do
      expect(generator.send(:model_name)).to eq("Guest")
    end

    it "derives the label" do
      expect(generator.send(:target_label)).to eq("Guests")
    end
  end
end
```

The column parsing spec is the most important one. It confirms that `first_name:string:required` correctly splits into a hash with `required: true`, while `email:email` (no third segment) defaults to `required: false`. The naming specs verify that `guests` as input produces `GuestsTarget` for the class, `Guest` for the model, and `Guests` for the label -- the singularization and titleization that the template depends on.

Notice that the specs instantiate the generator directly with `described_class.new(["guests", ...])` rather than invoking it through the Rails generator runner. This keeps the tests fast and focused: we are testing the logic, not the file I/O.

## Recap

- The **install generator** bootstraps the entire engine in one command: migration, initializer, importers directory, and route mount -- four steps that previously required reading the README and manually creating files.
- The **target generator** scaffolds a new import type with parsed column definitions, producing a ready-to-customize target file that follows the DSL conventions established in earlier parts of the series.
- The **migration template** uses ERB with `ActiveRecord::Migration.current_version` to match the host app's Rails version automatically, avoiding hardcoded version numbers.
- The **column parsing syntax** (`name:type[:required]`) mirrors `rails generate model` conventions, keeping the learning curve flat for Rails developers.
- The **initializer template** documents every configuration option with comments, making the engine's surface area discoverable without external documentation.

## Next up

The engine can now parse CSV files, but real-world data does not always arrive in a spreadsheet. In part 12, we extend the Source layer with **JSON and API sources** -- a JSON source that accepts files or raw text, and an API source that fetches data from HTTP endpoints with injectable parameters and authentication headers. The source abstraction we designed in part 6 is about to prove its worth.

---

*This is part 11 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: Controllers & Routing in a Rails Engine](#) | [Next: Adding JSON & API Sources](#)*
