# DataPorter -- A mountable Rails engine for data imports

Hey everyone!

If you've ever worked on a client-facing Rails app, you know the drill. At some point, someone sends you a CSV. "Can you import this into the app?" Sure, you write a quick Rake task, parse the file, done.

Then the next file arrives. The columns are in a different order. There's a semicolon separator instead of commas (thanks, European Excel). Some rows have missing data, others have typos in the email field. Your script crashes halfway through, you fix it, re-run, realize 200 rows were already inserted, now you have duplicates...

And the best part: you're the one running these imports. Every time. In the console. Because your client can't exactly run `rails runner import_contacts.rb` on their own.

I got tired of this loop. So I built [**DataPorter**](https://github.com/SerylLns/data_porter) -- a Rails engine that turns data imports into a self-service feature. Your clients upload their own files, see a preview of what's going to happen, fix their mistakes *before* importing, and you never touch a console again.

## The idea

You write a small Target class that describes your import (what columns you expect, how to save a record), and the engine gives you a full UI: file upload with drag-and-drop, interactive column mapping, data preview, real-time progress bar, error reports.

Here's what a target looks like in practice:

```ruby
class ProductTarget < DataPorter::Target
  label "Products"
  model_name "Product"
  sources :csv, :xlsx

  columns do
    column :name,  type: :string, required: true
    column :price, type: :decimal
    column :sku,   type: :string
  end

  def persist(record, context:)
    Product.create!(record.attributes)
  end
end
```

Mount the engine, visit `/imports`, done. Your users (or your client's team) can upload files and import data without bothering you.

## What's in the box

The stuff I kept rebuilding on every project, now built once:

- **CSV, XLSX, JSON, API** -- Four source types. CSV auto-detects delimiters and encoding (semicolons from European Excel, Latin-1, BOM... the classics)
- **Column mapping** -- Users match file headers to your fields with dropdowns. They can save mappings as templates for recurring imports
- **Preview step** -- See parsed data before committing. Required fields highlighted, validation errors visible per row
- **Dry run** -- "What if I import this?" Runs everything in a transaction and rolls back. Great for letting non-technical users test safely
- **Progress bar** -- Real-time, no ActionCable needed (just JSON polling)
- **Reject export** -- After import, download a CSV of failed rows with error messages. Clients love this one
- **Multi-tenant** -- One config line to scope imports per user, per hotel, per organization -- whatever your model is. Polymorphic, so it works with anything
- **Standalone UI** -- Ships its own layout with Turbo + Stimulus. No asset pipeline dependency, works with any Rails app

## Why I built it this way

A few decisions that might be interesting:

The engine is **completely business-agnostic**. It doesn't know anything about your models. All the domain logic (validation rules, persistence, transformations) lives in your Target classes. The engine just orchestrates the flow.

It's also designed to work **without authentication**. If your app has `current_user`, great, it'll capture it. If not (internal tool, admin panel), it still works fine. The scope feature is opt-in.

I went with **Phlex components** for the UI instead of partials. Faster rendering, easier to test, and I genuinely enjoy writing views in Ruby now.

## Where it's at

We're using it in production on a concierge management app (hotel contacts, booking imports). It handles CSV, XLSX, JSON and API imports with the same Target, which is pretty satisfying.

- 413 specs, 0 failures, 0 Rubocop offenses
- Ruby >= 3.2, Rails >= 7.0
- MIT license

I'm also writing a blog series on dev.to that traces the entire creation of the gem from scratch -- the architecture decisions, the TDD workflow, the bugs, everything. If you're interested in the "how it was built" side, I'll drop the link in the comments.

## Would love your feedback

This is my first published gem so I'm definitely open to criticism:

- Does the Target DSL feel right? Too magic? Not enough?
- Missing a feature that would be a dealbreaker for your use case?
- Anything that looks off in the repo?

GitHub: https://github.com/SerylLns/data_porter
RubyGems: https://rubygems.org/gems/data_porter

Happy to answer any questions!
