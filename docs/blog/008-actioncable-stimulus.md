---
title: "Building DataPorter #8 -- Real-time Progress with ActionCable & Stimulus"
series: "Building DataPorter - A Data Import Engine for Rails"
part: 8
tags: [ruby, rails, rails-engine, gem-development, actioncable, stimulus, real-time, websockets]
published: false
---

# Real-time Progress with ActionCable & Stimulus

> How to push live progress updates from a background import job to the browser using a Broadcaster service, an ActionCable channel, and a Stimulus controller -- so users never stare at a dead spinner again.

## Context

This is part 8 of the series where we build **DataPorter**, a mountable Rails engine for data import workflows. In [part 7](#), we built the Orchestrator -- the class that coordinates the parse-then-import workflow, transitions state, handles per-record errors, and delegates to ActiveJob for background processing.

The Orchestrator works, but it works silently. The user clicks "Import", the job goes into the queue, and the page sits there. There is no indication of whether the import is 10% done, 90% done, or failed entirely. The only way to find out is to refresh the page and check the status column. For a 50,000-row CSV that takes two minutes, that is a terrible experience.

In this article, we build the real-time progress layer: a server-side Broadcaster that pushes updates over ActionCable, a channel that routes those updates to the right browser tab, and a Stimulus controller that animates a progress bar and auto-reloads when the import finishes.

## The problem

Background jobs are invisible by default. ActiveJob processes work in a separate process (or even a separate server), and the browser has no built-in way to know when a job completes or how far along it is. The standard workarounds are polling (the browser asks "are we done yet?" every few seconds) or server-sent events. Polling works but wastes requests and introduces latency equal to half the polling interval on average. SSE is one-directional and requires holding an HTTP connection open, which complicates deployments behind load balancers.

Rails ships with ActionCable, a WebSocket framework that integrates with the same authentication and session infrastructure the rest of the app uses. Since DataPorter is a Rails engine, it can assume ActionCable is available. The challenge is designing the broadcasting layer so it stays decoupled from the Orchestrator, uses a channel naming scheme that does not collide with the host app, and provides a clean Stimulus integration that works without the host developer writing any JavaScript.

## What we're building

Here is the flow from server to browser:

```
Orchestrator#import!
  |
  |-- for each record:
  |     Broadcaster#progress(current, total)
  |       --> ActionCable.server.broadcast("data_porter/imports/42", { status: :processing, percentage: 65, ... })
  |             --> ImportChannel streams to subscriber
  |                   --> Stimulus progress_controller updates the bar
  |
  |-- on success:
  |     Broadcaster#success
  |       --> { status: :success }
  |             --> Stimulus reloads the page
  |
  |-- on failure:
        Broadcaster#failure(message)
          --> { status: :failure, error: "..." }
                --> Stimulus reloads the page
```

Three objects, three layers. The Broadcaster knows how to format messages. The ImportChannel knows how to route them. The Stimulus controller knows how to render them. None of them knows about the others' internals.

## Implementation

### Step 1 -- The Broadcaster service

The Broadcaster is a plain Ruby object that wraps `ActionCable.server.broadcast` with import-specific semantics:

```ruby
# lib/data_porter/broadcaster.rb
module DataPorter
  class Broadcaster
    def initialize(import_id)
      prefix = DataPorter.configuration.cable_channel_prefix
      @channel = "#{prefix}/imports/#{import_id}"
    end

    def progress(current, total)
      percentage = ((current.to_f / total) * 100).round
      broadcast(status: :processing, percentage: percentage, current: current, total: total)
    end

    def success
      broadcast(status: :success)
    end

    def failure(message)
      broadcast(status: :failure, error: message)
    end

    private

    def broadcast(message)
      ActionCable.server.broadcast(@channel, message)
    end
  end
end
```

The constructor builds the channel name from the configured prefix and the import ID. This is the only place the naming convention lives -- the channel and the Stimulus controller both derive from it, but neither constructs it independently. The three public methods correspond to the three states the browser cares about: work is in progress, work succeeded, or work failed. The `progress` method computes the percentage server-side so the client does not need to do arithmetic.

The channel name uses a path-style format (`data_porter/imports/42`) rather than a class-style format (`DataPorter::ImportChannel:42`). This is a deliberate choice: the path format reads naturally in logs, avoids Ruby namespace syntax in JavaScript, and the prefix segment makes collisions with host app channels impossible.

The Broadcaster is designed to be instantiated inside the Orchestrator's import loop. Here is how it plugs in:

```ruby
# Inside Orchestrator#import_records (conceptual)
broadcaster = Broadcaster.new(@data_import.id)
importable.each_with_index do |record, index|
  persist_record(record, context, results)
  broadcaster.progress(index + 1, importable.size)
end
broadcaster.success
```

One `progress` call per record. For a 10,000-row import, that means 10,000 WebSocket messages. This is acceptable because ActionCable broadcasts are cheap (an in-memory pub/sub when using the async adapter, a Redis PUBLISH when using Redis), and the Stimulus controller handles them idempotently -- it just sets a CSS width, so skipped frames cause no harm.

### Step 2 -- The ImportChannel

The channel is the thinnest class in the entire engine:

```ruby
# app/channels/data_porter/import_channel.rb
module DataPorter
  class ImportChannel < ActionCable::Channel::Base
    def subscribed
      prefix = DataPorter.configuration.cable_channel_prefix
      stream_from "#{prefix}/imports/#{params[:id]}"
    end
  end
end
```

That is the entire file. When a browser subscribes with `{ channel: "DataPorter::ImportChannel", id: 42 }`, the channel constructs the same stream name the Broadcaster uses and calls `stream_from`. No authorization logic, no custom actions, no rejection handling.

This simplicity is intentional. Authorization for import access should happen at the controller level (before the page renders), not at the channel level. By the time the user sees the progress bar, they have already been authorized to view that import. Adding channel-level auth would duplicate the host app's authorization logic inside the engine, and the engine does not know whether the host uses Devise, Pundit, or a custom system.

The channel name symmetry is critical: the Broadcaster writes to `"#{prefix}/imports/#{id}"` and the channel reads from `"#{prefix}/imports/#{params[:id]}"`. If these ever diverge, messages go nowhere. Using the same `cable_channel_prefix` configuration value in both classes guarantees they stay in sync.

### Step 3 -- The Stimulus progress controller

On the browser side, a Stimulus controller subscribes to the channel and updates the DOM:

```javascript
// app/javascript/data_porter/progress_controller.js
import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["bar", "text"]
  static values = { id: Number }

  connect() {
    this.subscription = createConsumer().subscriptions.create(
      { channel: "DataPorter::ImportChannel", id: this.idValue },
      {
        received: (data) => {
          if (data.status === "processing") {
            this.updateProgress(data.percentage)
          } else {
            window.location.reload()
          }
        }
      }
    )
  }

  updateProgress(percentage) {
    if (this.hasBarTarget) {
      this.barTarget.style.width = `${percentage}%`
      this.textTarget.textContent = `${percentage}%`
    }
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }
}
```

The controller declares two targets (`bar` and `text`) and one value (`id`). The corresponding HTML looks like this:

```html
<div data-controller="data-porter--progress" data-data-porter--progress-id-value="42">
  <div data-data-porter--progress-target="bar" style="width: 0%"></div>
  <span data-data-porter--progress-target="text">0%</span>
</div>
```

On `connect`, the controller creates an ActionCable subscription. The `received` callback handles the two-branch logic: if the status is `processing`, update the progress bar width and text; for anything else (`success` or `failure`), reload the page. The reload is the simplest possible terminal action -- the server-rendered page will show the completed import with its report, or the failed import with its error. No client-side state management needed.

The `disconnect` callback unsubscribes from the channel, which is important for single-page-app-style navigation where Stimulus controllers connect and disconnect as the user moves between pages. Without it, orphaned subscriptions would accumulate and leak memory.

Three design choices are worth noting here. First, we use `createConsumer()` rather than importing a shared consumer instance. In an engine context, we cannot assume the host app exports its consumer, so we create our own. ActionCable deduplicates connections internally, so multiple consumers pointing at the same WebSocket endpoint share a single connection. Second, the `hasBarTarget` guard means the controller degrades gracefully if the HTML does not include the targets -- useful during Turbo transitions where the DOM might be partially rendered. Third, the page reload on completion means the engine does not need to ship Turbo Stream templates or partial update logic for the result screen. The server renders the final state once, and the client gets there by reloading.

### Step 4 -- The cable_channel_prefix configuration

The channel name prefix is configurable through the engine's Configuration class:

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
    @cable_channel_prefix = "data_porter"
    # ...
  end
end
```

The default prefix is `"data_porter"`, which produces channel names like `"data_porter/imports/42"`. A host app can override it:

```ruby
# config/initializers/data_porter.rb
DataPorter.configure do |config|
  config.cable_channel_prefix = "my_app_imports"
end
```

This matters for two reasons. First, if the host app runs multiple engines that use ActionCable, unique prefixes prevent channel name collisions. Second, if the host app's ActionCable adapter uses Redis, the prefix becomes part of the Redis pub/sub channel name, and operations teams may want it to match their naming conventions.

## Decisions & tradeoffs

| Decision | We chose | Over | Because |
|----------|----------|------|---------|
| Real-time transport | ActionCable (WebSockets) | Polling or SSE | Rails ships ActionCable; no extra dependencies, integrates with existing auth, bidirectional even though we only need server-to-client |
| Broadcast granularity | One message per record | Batched (every N records) or throttled (every N seconds) | Simplicity; ActionCable broadcasts are cheap, and the Stimulus controller handles high-frequency updates idempotently by just setting a CSS width |
| Completion behavior | `window.location.reload()` | Turbo Stream partial updates | The engine cannot predict what the host app's result page looks like; a full reload lets the server render the final state with its own layout and components |
| Channel authorization | None (deferred to controller) | `reject` in `subscribed` based on user ownership | The engine does not know the host's auth system; by the time the user sees the progress bar, the controller has already authorized access |
| Consumer creation | `createConsumer()` per controller | Shared global consumer | The engine cannot assume the host app exports a consumer; ActionCable deduplicates WebSocket connections internally |
| Channel naming | Configurable prefix (`cable_channel_prefix`) | Hardcoded `"data_porter"` | Avoids collisions in multi-engine apps and lets ops teams control Redis pub/sub channel naming |

## Testing it

### Broadcaster specs

The Broadcaster specs stub `ActionCable.server.broadcast` and verify the message payloads:

```ruby
# spec/data_porter/broadcaster_spec.rb
RSpec.describe DataPorter::Broadcaster do
  let(:broadcaster) { described_class.new(42) }

  before do
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe "#progress" do
    it "broadcasts processing status with percentage" do
      broadcaster.progress(50, 100)

      expect(ActionCable.server).to have_received(:broadcast).with(
        "data_porter/imports/42",
        { status: :processing, percentage: 50, current: 50, total: 100 }
      )
    end

    it "rounds percentage" do
      broadcaster.progress(1, 3)

      expect(ActionCable.server).to have_received(:broadcast).with(
        "data_porter/imports/42",
        { status: :processing, percentage: 33, current: 1, total: 3 }
      )
    end
  end

  describe "#success" do
    it "broadcasts success status" do
      broadcaster.success

      expect(ActionCable.server).to have_received(:broadcast).with(
        "data_porter/imports/42",
        { status: :success }
      )
    end
  end

  describe "#failure" do
    it "broadcasts failure with error message" do
      broadcaster.failure("Something went wrong")

      expect(ActionCable.server).to have_received(:broadcast).with(
        "data_porter/imports/42",
        { status: :failure, error: "Something went wrong" }
      )
    end
  end
end
```

The key assertion pattern: verify the exact channel name and the exact message hash. Because the Broadcaster is a pure wrapper around `ActionCable.server.broadcast`, stubbing that single method lets us test all behavior without a WebSocket server or a browser.

The prefix configuration is also tested:

```ruby
describe "channel name" do
  it "uses configured cable_channel_prefix" do
    DataPorter.configuration.cable_channel_prefix = "custom"
    custom_broadcaster = described_class.new(99)

    custom_broadcaster.success

    expect(ActionCable.server).to have_received(:broadcast).with(
      "custom/imports/99",
      { status: :success }
    )
  ensure
    DataPorter.configuration.cable_channel_prefix = "data_porter"
  end
end
```

The `ensure` block resets the prefix after the test, preventing configuration leakage between examples. This is a common pattern when testing configurable singletons.

### Channel spec

The ImportChannel spec is minimal because the class itself is minimal:

```ruby
# spec/data_porter/import_channel_spec.rb
RSpec.describe DataPorter::ImportChannel do
  it "inherits from ActionCable::Channel::Base" do
    expect(described_class.superclass).to eq(ActionCable::Channel::Base)
  end
end
```

A fuller integration test would use `ActionCable::Channel::TestCase` to assert that `subscribed` calls `stream_from` with the correct channel name. For now, we rely on the fact that the Broadcaster specs prove the channel name format, and the channel uses the same construction logic. If the two diverge, the Broadcaster specs will catch it before any integration test would.

### JavaScript spec

Testing a Stimulus controller from RSpec is unconventional, but for an engine that ships JavaScript, it is valuable to at least verify the source file's structure:

```ruby
# spec/data_porter/progress_controller_js_spec.rb
RSpec.describe "progress_controller.js" do
  let(:js_path) { File.expand_path("../../app/javascript/data_porter/progress_controller.js", __dir__) }
  let(:content) { File.read(js_path) }

  it "imports Stimulus Controller" do
    expect(content).to include('import { Controller } from "@hotwired/stimulus"')
  end

  it "imports ActionCable consumer" do
    expect(content).to include('import { createConsumer } from "@rails/actioncable"')
  end

  it "defines bar and text targets" do
    expect(content).to include('static targets = ["bar", "text"]')
  end

  it "subscribes to ImportChannel on connect" do
    expect(content).to include("DataPorter::ImportChannel")
  end

  it "unsubscribes on disconnect" do
    expect(content).to include("this.subscription?.unsubscribe()")
  end
end
```

These are not behavioral tests -- they are structural assertions that guard against accidental breakage. If someone renames a target or removes the unsubscribe call, the spec fails. For real behavioral testing of the Stimulus controller, you would use a JavaScript test runner (Jest, Vitest) or a system test with Capybara and a real WebSocket connection. That level of integration testing is covered in part 13 when we set up the full test infrastructure.

## Recap

- The **Broadcaster** is a plain Ruby service that wraps `ActionCable.server.broadcast` with three semantic methods: `progress`, `success`, and `failure`. It constructs the channel name from a configurable prefix and the import ID.
- The **ImportChannel** is a one-method ActionCable channel that streams from the same channel name the Broadcaster writes to. It contains no authorization logic -- that responsibility stays in the controller layer.
- The **Stimulus progress controller** subscribes on `connect`, updates a progress bar on `processing` messages, reloads the page on `success` or `failure`, and cleans up the subscription on `disconnect`.
- The **cable_channel_prefix** configuration option prevents channel name collisions with the host app and gives operations teams control over naming.

## Next up

The import now runs in the background and pushes live progress to the browser. But the progress bar needs a page to live on, and right now the engine has no UI. In part 9, we build the **view layer with Phlex and Tailwind** -- auto-generated preview tables from the target DSL, status badges, and scoped CSS that does not leak into the host app.

---

*This is part 8 of the series "Building DataPorter - A Data Import Engine for Rails". [Previous: The Orchestrator](#) | [Next: Building the UI with Phlex & Tailwind](#)*
