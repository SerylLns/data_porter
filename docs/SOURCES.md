# Sources

DataPorter supports four source types. Each source reads data from a different format and feeds it through the same parsing pipeline.

## CSV

Upload a CSV file. Headers are extracted automatically and presented in the [column mapping](MAPPING.md) step. Configure header mappings with `csv_mapping` in your [Target](TARGETS.md) when file headers don't match your column names.

Custom separator:

```ruby
import.config = { "separator" => ";" }
```

## XLSX

Upload an Excel `.xlsx` file. Uses the same `csv_mapping` for header-to-column mapping as CSV. By default the first sheet is parsed; select a different sheet via config:

```ruby
import.config = { "sheet_index" => 1 }
```

Powered by [creek](https://github.com/pythonicrubyist/creek) for streaming, memory-efficient parsing.

## JSON

Upload a JSON file. Use `json_root` in your Target to specify the path to the records array. Raw JSON arrays are supported without `json_root`.

```ruby
json_root "data.users"
```

Given `{ "data": { "users": [...] } }`, records are extracted from `data.users`.

## API

Fetch records from an external API endpoint. No file upload is needed -- the engine calls the API directly.

### Basic usage

```ruby
api_config do
  endpoint "https://api.example.com/data"
  headers({ "Authorization" => "Bearer token" })
  response_root "results"
end
```

| Option | Type | Description |
|---|---|---|
| `endpoint` | String or Proc | URL to fetch records from |
| `headers` | Hash or Proc | HTTP headers sent with the request |
| `response_root` | String | Key in the JSON response containing the records array (omit for top-level arrays) |

### Dynamic endpoints and headers

Both `endpoint` and `headers` accept lambdas for runtime values. The endpoint lambda receives the import's `config` hash:

```ruby
api_config do
  endpoint ->(params) { "https://api.example.com/events?page=#{params[:page]}" }
  headers -> { { "Authorization" => "Bearer #{ENV['API_TOKEN']}" } }
  response_root "data"
end
```

### Full example

```ruby
class EventTarget < DataPorter::Target
  label "Events"
  model_name "Event"
  sources :api

  api_config do
    endpoint "https://api.example.com/events"
    headers -> { { "Authorization" => "Bearer #{ENV['EVENTS_API_KEY']}" } }
    response_root "events"
  end

  columns do
    column :name,     type: :string, required: true
    column :date,     type: :date
    column :venue,    type: :string
    column :capacity, type: :integer
  end

  def persist(record, context:)
    Event.create!(record.attributes)
  end
end
```

When a user creates an import with source type **API**, the engine skips file upload entirely, calls the configured endpoint, parses the JSON response, and feeds the records through the same preview/validate/import pipeline as file-based sources.
