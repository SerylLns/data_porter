---
title: "Building DataPorter #9 -- Building the UI with Phlex & Tailwind"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 9
tags: [ruby, rails, rails-engine, gem-development, phlex, components, tailwind, ui]
published: false
---

# Building the UI with Phlex & Tailwind

> How to build a full component library for a Rails engine using Phlex, scope all CSS with a `dp-` prefix so styles never leak into the host app, and generate preview tables dynamically from the Target DSL.

## Context

This is part 9 of the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 8](#), we wired up ActionCable and Stimulus so users get real-time progress updates as imports run in the background.

We now have a working engine: targets define imports, sources parse files, the Orchestrator coordinates the workflow, and ActionCable pushes updates to the browser. But the browser has nothing to render. Every status, every preview row, every progress bar needs a component. In this article, we build the entire view layer -- seven Phlex components that turn DataPorter's internal data structures into HTML the user can actually see.

## Why Phlex (not ERB or ViewComponent)

A Rails engine's view layer needs to ship inside the gem. That immediately rules out the typical ERB-in-`app/views` workflow, because template files in engines are fragile -- they depend on the host app's layout, helpers, and asset pipeline. We need components that are self-contained Ruby objects: no template files to resolve, no helper dependencies, no partial lookup paths.

ViewComponent solves some of this, but it still relies on sidecar templates or inline `erb` calls by default. Phlex takes a different approach: the template *is* the Ruby class. A component is a plain object with a `view_template` method that uses a Ruby DSL to emit HTML. No template resolution. No string interpolation. No implicit dependencies. The component is just a class you instantiate and call.

For a gem, this is ideal. Every component lives in `lib/`, ships with the gem, and renders anywhere -- in a controller, in a test, in a Turbo Stream. There is no asset pipeline to configure, no `app/components` directory to worry about, and no risk of template name collisions with the host app.

The other constraint is CSS isolation. DataPorter's components need styles, but those styles must not leak into the host app's design system. We solve this with a `dp-` prefix convention on every CSS class, which we will cover in detail below.

## Implementation

### Step 1 -- The Base component

Every DataPorter component inherits from a shared base class that extends `Phlex::HTML`:

```ruby
# lib/data_porter/components/base.rb
require "phlex"

module DataPorter
  module Components
    class Base < Phlex::HTML
    end
  end
end
```

This is intentionally minimal. The base class exists as a single point of inheritance so we can add shared behavior later -- a common CSS helper, a default wrapper, an HTML safety policy -- without touching every component. Right now it does nothing but establish the hierarchy. That is fine. The value is in the seam, not the code.

The module barrel file requires all components in order:

```ruby
# lib/data_porter/components.rb
require_relative "components/base"
require_relative "components/status_badge"
require_relative "components/summary_cards"
require_relative "components/preview_table"
require_relative "components/progress_bar"
require_relative "components/results_summary"
require_relative "components/failure_alert"

module DataPorter
  module Components
  end
end
```

### Step 2 -- StatusBadge: the simplest component

The StatusBadge renders a single `<span>` with the import's current status. It demonstrates the pattern every component follows:

```ruby
# lib/data_porter/components/status_badge.rb
module DataPorter
  module Components
    class StatusBadge < Base
      def initialize(status:)
        super()
        @status = status.to_s
      end

      def view_template
        span(class: "dp-badge dp-badge--#{@status}") { @status.capitalize }
      end
    end
  end
end
```

The constructor takes a keyword argument and calls `super()` -- Phlex requires this. The `view_template` method emits a span with two CSS classes: a base class `dp-badge` for shared badge styles, and a modifier class `dp-badge--#{@status}` for status-specific colors. The naming follows BEM conventions, but with the `dp-` prefix to scope everything to DataPorter.

Rendering it is a method call:

```ruby
DataPorter::Components::StatusBadge.new(status: "completed").call
# => '<span class="dp-badge dp-badge--completed">Completed</span>'
```

No partial lookup, no view context, no render helpers. Just instantiate and call.

### Step 3 -- SummaryCards: parsing report data into a dashboard

After the Orchestrator's `parse!` phase completes, the import has a Report object with counts for each record status. The SummaryCards component turns that into a row of four cards:

```ruby
# lib/data_porter/components/summary_cards.rb
module DataPorter
  module Components
    class SummaryCards < Base
      def initialize(report:)
        super()
        @report = report
      end

      def view_template
        div(class: "dp-summary-cards") do
          card("dp-card--complete", @report.complete_count, "Ready")
          card("dp-card--partial", @report.partial_count, "Incomplete")
          card("dp-card--missing", @report.missing_count, "Missing")
          card("dp-card--duplicate", @report.duplicate_count, "Duplicates")
        end
      end

      private

      def card(css_class, count, label)
        div(class: "dp-card #{css_class}") do
          strong { count.to_s }
          plain " #{label}"
        end
      end
    end
  end
end
```

The private `card` method extracts the repeated pattern: a `div` with a modifier class, a bold count, and a label. Each card gets a status-specific class (`dp-card--complete`, `dp-card--partial`, etc.) so the host app's stylesheet -- or DataPorter's own default styles -- can color-code them. The `plain` helper emits raw text without wrapping it in an element, keeping the markup minimal.

This component takes a single `report:` argument and does not care where the report came from. In production it comes from `data_import.report`. In a test, you can pass a plain `Report.new(complete_count: 10, ...)`. The component has no database dependency.

### Step 4 -- PreviewTable: dynamic columns from the Target DSL

The PreviewTable is the most complex component and the one that justifies choosing Phlex. It builds an HTML table whose columns are defined dynamically by the Target class's column DSL -- the same DSL we built in part 5. A target with two columns produces a table with two data columns. A target with ten produces ten. No template changes needed.

```ruby
# lib/data_porter/components/preview_table.rb
module DataPorter
  module Components
    class PreviewTable < Base
      def initialize(columns:, records:)
        super()
        @columns = columns
        @records = records
      end

      def view_template
        div(class: "dp-preview-table") do
          table(class: "dp-table") do
            render_header
            render_body
          end
        end
      end

      private

      def render_header
        thead do
          tr do
            th { "#" }
            th { "Status" }
            @columns.each { |col| th { col.label } }
            th { "Errors" }
          end
        end
      end

      def render_body
        tbody do
          @records.each { |record| render_row(record) }
        end
      end

      def render_row(record)
        tr(class: "dp-row--#{record.status}") do
          td { record.line_number.to_s }
          td { record.status }
          @columns.each { |col| td { record.data[col.name.to_s].to_s } }
          td(class: "dp-errors") { error_messages(record) }
        end
      end

      def error_messages(record)
        record.errors_list.map(&:message).join(", ")
      end
    end
  end
end
```

The header row always starts with a line number column and a status column, then iterates over the target's `_columns` to produce one `<th>` per declared column using `col.label` (the human-readable name), and ends with an errors column. The body does the same iteration for each record, pulling values from `record.data` by column name.

Each row gets a `dp-row--#{record.status}` class. A row with status `complete` gets `dp-row--complete`, a row with `missing` gets `dp-row--missing`. This lets the stylesheet highlight problem rows -- red background for missing data, yellow for partial, green for complete -- without any conditional logic in the component.

The key design choice here is that the PreviewTable takes `columns:` and `records:` as separate arguments rather than a DataImport object. This keeps it decoupled: the component does not need to know how to resolve a target or load records from the database. The controller (or whoever renders it) passes the data in, and the component turns it into HTML.

### Step 5 -- ProgressBar: bridging Phlex and Stimulus

The ProgressBar component is where server-rendered Phlex meets client-side Stimulus. It renders the initial HTML with Stimulus data attributes, and the Stimulus controller (from part 8) takes over to animate the bar as ActionCable pushes updates:

```ruby
# lib/data_porter/components/progress_bar.rb
module DataPorter
  module Components
    class ProgressBar < Base
      def initialize(import_id:)
        super()
        @import_id = import_id
      end

      def view_template
        div(class: "dp-progress", **stimulus_controller_attrs) do
          render_bar
        end
      end

      private

      def render_bar
        div(class: "dp-progress-bar",
            data_data_porter__progress_target: "bar",
            style: "width: 0%") do
          span(data_data_porter__progress_target: "text") { "0%" }
        end
      end

      def stimulus_controller_attrs
        {
          data_controller: "data-porter--progress",
          data_data_porter__progress_id_value: @import_id.to_s
        }
      end
    end
  end
end
```

The Stimulus naming convention for engines uses the `data-porter--progress` format -- double dash separating the namespace from the controller name. Phlex's HTML DSL converts Ruby keyword arguments with underscores to hyphenated HTML attributes, so `data_data_porter__progress_target` becomes `data-data-porter--progress-target` in the output. The double underscore in Ruby maps to the double dash that Stimulus expects for namespaced controllers.

The component renders the bar at `width: 0%`. The Stimulus controller subscribes to the ActionCable channel using the `id_value` and updates the width and text as progress events arrive. The Phlex component's only job is to emit the correct initial HTML with the right data attributes. It does not know about ActionCable or JavaScript.

### Step 6 -- ResultsSummary and FailureAlert: post-import components

After the import completes, two components display the outcome. ResultsSummary shows the final counts:

```ruby
# lib/data_porter/components/results_summary.rb
module DataPorter
  module Components
    class ResultsSummary < Base
      def initialize(report:)
        super()
        @report = report
      end

      def view_template
        div(class: "dp-results") do
          p { "Created: #{@report.imported_count}" }
          p { "Errors: #{@report.errored_count}" }
        end
      end
    end
  end
end
```

FailureAlert handles the catastrophic failure case -- when the Orchestrator catches an exception and transitions to `failed`:

```ruby
# lib/data_porter/components/failure_alert.rb
module DataPorter
  module Components
    class FailureAlert < Base
      def initialize(report:)
        super()
        @report = report
      end

      def view_template
        div(class: "dp-alert dp-alert--danger") do
          @report.error_reports.each do |err|
            p { err.message }
          end
        end
      end
    end
  end
end
```

Both are intentionally simple. The ResultsSummary renders two paragraphs. The FailureAlert iterates over error reports and renders each message. There is no conditional logic, no branching, no fallback states. The controller decides which component to render based on the import's status. The components just render what they are given.

## The `dp-` CSS prefix strategy

Every CSS class in the component library starts with `dp-`: `dp-badge`, `dp-table`, `dp-progress`, `dp-alert`, `dp-card`, `dp-row`, `dp-errors`, `dp-results`, `dp-summary-cards`, `dp-preview-table`. This is a manual namespacing strategy that solves a real problem: a Rails engine's styles must coexist with the host app's styles without collisions.

If DataPorter used generic class names like `badge`, `table`, or `alert`, they would conflict with Bootstrap, Tailwind UI, or whatever the host app uses. If we used CSS modules or Shadow DOM, we would add complexity and browser constraints that a server-rendered Rails app should not need.

The `dp-` prefix is the simplest approach that works. It is a convention, not a mechanism -- there is nothing stopping someone from using `dp-badge` in their own app. But it is unlikely, and it is obvious when it happens. The naming follows BEM-style modifiers (`dp-badge--failed`, `dp-row--complete`, `dp-card--partial`) so the structure is predictable.

DataPorter ships with a default stylesheet that targets these classes. Host apps can override any of them. Because every class is prefixed, a blanket override like `.dp-badge { ... }` will only affect DataPorter's badges without touching anything else on the page.

This strategy also plays well with Tailwind. If the host app uses Tailwind, they can style DataPorter's components with `@apply` inside a `dp-`-prefixed selector, or they can use Tailwind's `@layer` to scope overrides. The prefix gives them a clean hook without requiring any configuration in DataPorter itself.

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| Component framework | Phlex | ERB partials, ViewComponent | Components are plain Ruby objects in `lib/`; no template resolution, no sidecar files, no asset pipeline dependency |
| CSS scoping | Manual `dp-` prefix on all classes | CSS modules, Shadow DOM, Tailwind prefix config | Simplest approach that prevents collisions; no build step, no browser constraints, works everywhere |
| Naming convention | BEM-style with `dp-` namespace (`dp-badge--failed`) | Flat class names, utility classes | Predictable structure; modifiers make status-specific styling obvious |
| PreviewTable inputs | Separate `columns:` and `records:` arguments | A single `data_import:` argument | Decouples the component from the database; testable with plain objects |
| ProgressBar strategy | Server-render initial HTML, let Stimulus animate | Render progress entirely client-side | The initial state (0%) is valid HTML; progressive enhancement means the page works even if JS fails to load |
| Component granularity | Seven small components | One large "import view" component | Each component is independently testable, replaceable, and composable |
| Base class | Empty `Base < Phlex::HTML` | Components inherit directly from `Phlex::HTML` | Provides a seam for future shared behavior without touching every component |

## Testing it

Phlex components are pure Ruby objects, which means testing them does not require a view context, a request, or a Rails controller. You instantiate the component and call `call` to get the HTML string:

```ruby
# spec/data_porter/components/status_badge_spec.rb
RSpec.describe DataPorter::Components::StatusBadge do
  def render(component)
    component.call
  end

  it "renders a span with status text" do
    html = render(described_class.new(status: "completed"))
    expect(html).to include("Completed")
    expect(html).to include("dp-badge")
  end

  it "includes status-specific CSS class" do
    html = render(described_class.new(status: "failed"))
    expect(html).to include("dp-badge--failed")
  end

  it "renders all valid statuses" do
    %w[pending parsing previewing importing completed failed].each do |status|
      html = render(described_class.new(status: status))
      expect(html).to include(status.capitalize)
    end
  end
end
```

The pattern is the same for every component: define a local `render` helper that calls `component.call`, construct the component with the right arguments, and assert against the HTML string. No Capybara, no request specs, no browser.

The PreviewTable spec is the most interesting because it uses a real anonymous Target class to generate columns:

```ruby
# spec/data_porter/components/preview_table_spec.rb
RSpec.describe DataPorter::Components::PreviewTable do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"

      columns do
        column :first_name, type: :string, required: true
        column :last_name, type: :string
      end
    end
  end

  let(:record) do
    DataPorter::StoreModels::ImportRecord.new(
      line_number: 1,
      status: "complete",
      data: { "first_name" => "Alice", "last_name" => "Smith" }
    )
  end

  it "renders column headers from target" do
    html = render(described_class.new(columns: target_class._columns, records: [record]))

    expect(html).to include("First name")
    expect(html).to include("Last name")
  end

  it "renders record data in rows" do
    html = render(described_class.new(columns: target_class._columns, records: [record]))

    expect(html).to include("Alice")
    expect(html).to include("Smith")
  end

  it "includes status-specific row class" do
    html = render(described_class.new(columns: target_class._columns, records: [record]))
    expect(html).to include("dp-row--complete")
  end
end
```

This test proves the full loop: the Target DSL declares columns, the PreviewTable reads those column definitions, and the rendered HTML contains the right headers and data. If someone adds a column to the target, the table grows automatically. No template change required.

The ProgressBar spec verifies the Stimulus wiring without needing JavaScript:

```ruby
# spec/data_porter/components/progress_bar_spec.rb
RSpec.describe DataPorter::Components::ProgressBar do
  it "renders a progress bar with Stimulus data attributes" do
    html = render(described_class.new(import_id: 42))

    expect(html).to include("dp-progress")
    expect(html).to include("data-controller")
    expect(html).to include("data-porter--progress")
    expect(html).to include("42")
  end

  it "renders bar and text targets" do
    html = render(described_class.new(import_id: 1))

    expect(html).to include('data-data-porter--progress-target="bar"')
    expect(html).to include('data-data-porter--progress-target="text"')
  end
end
```

We do not test that the bar animates. We test that the HTML contract between Phlex and Stimulus is correct -- the right controller name, the right target names, the right value attribute. If those are present, the Stimulus controller (tested separately) will work.

## Recap

- **Phlex** lets us ship components as plain Ruby classes in `lib/`, with no template files, no view context, and no asset pipeline dependency -- ideal for a Rails engine gem.
- The **`dp-` prefix** on every CSS class prevents style collisions with the host app, using the simplest possible approach: a naming convention.
- The **PreviewTable** builds its columns dynamically from the Target DSL, so adding a column to a target automatically adds a column to the preview -- no template changes.
- The **ProgressBar** bridges server-rendered Phlex and client-side Stimulus by emitting the correct data attributes at render time, then letting JavaScript handle animation.
- Every component is **independently testable** by calling `component.call` and asserting against the returned HTML string -- no browser, no request context, no Capybara.

## Next up

We have components, but nothing renders them yet. In part 10, we build the **controllers and routing layer** for the engine -- how ImportsController inherits from the host app's parent controller, how engine routes are namespaced, and how Turbo integration ties the components to the import workflow. The tricky part: making authentication flow from the host app into the engine without coupling to any specific auth library.

---

*This is part 9 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: Real-time Progress with ActionCable & Stimulus](#) | [Next: Controllers & Routing in a Rails Engine](#)*
