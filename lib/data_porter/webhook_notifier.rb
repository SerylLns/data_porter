# frozen_string_literal: true

module DataPorter
  module WebhookNotifier
    EVENT_MAP = {
      "import.started" => :started,
      "import.completed" => :completed,
      "import.failed" => :failed,
      "import.parsed" => :parsed
    }.freeze

    module_function

    def notify(data_import, event)
      webhooks = resolve_webhooks(data_import)
      return if webhooks.nil? || webhooks.empty?

      event_sym = EVENT_MAP.fetch(event)
      matching = webhooks.select { |w| w.events.include?(event_sym) }
      return if matching.empty?

      matching.each do |webhook|
        payload = build_payload(data_import, event, webhook)
        DataPorter::WebhookJob.perform_later(webhook.url, payload, webhook.headers.dup)
      end
    end

    def resolve_webhooks(data_import)
      data_import.target_class._webhooks
    end

    def build_payload(data_import, event, webhook)
      data = default_payload(data_import, event)
      data = webhook.payload.call(data_import, event, data) if webhook.payload
      data.to_json
    end

    def default_payload(data_import, event)
      {
        "event" => event,
        "timestamp" => Time.current.iso8601,
        "import" => import_data(data_import, event)
      }
    end

    def import_data(data_import, event)
      base = base_import_data(data_import)
      merge_event_data(base, data_import, event)
    end

    def base_import_data(data_import)
      {
        "id" => data_import.id,
        "target_key" => data_import.target_key,
        "source_type" => data_import.source_type
      }
    end

    def merge_event_data(base, data_import, event)
      case event
      when "import.completed" then merge_completed(base, data_import)
      when "import.failed" then merge_failed(base, data_import)
      when "import.parsed" then merge_parsed(base, data_import)
      when "import.started" then merge_started(base, data_import)
      else base
      end
    end

    def merge_completed(base, data_import)
      report = data_import.report
      base.merge(
        "imported_count" => report&.imported_count.to_i,
        "errored_count" => report&.errored_count.to_i
      )
    end

    def merge_failed(base, data_import)
      message = first_error_message(data_import.report)
      base.merge("error_message" => message)
    end

    def first_error_message(report)
      errors = report&.error_reports
      errors&.first&.message
    end

    def merge_parsed(base, data_import)
      report = data_import.report
      base.merge(
        "records_count" => report&.records_count.to_i,
        "complete_count" => report&.complete_count.to_i,
        "partial_count" => report&.partial_count.to_i
      )
    end

    def merge_started(base, data_import)
      base.merge("records_count" => data_import.records.size)
    end
  end
end
