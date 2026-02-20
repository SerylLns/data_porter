# frozen_string_literal: true

module DataPorter
  module DSL
    VALID_WEBHOOK_EVENTS = %i[started completed failed parsed].freeze

    Webhook = Struct.new(:url, :events, :headers, :payload, keyword_init: true) do
      def initialize(url:, events: VALID_WEBHOOK_EVENTS, headers: {}, payload: nil)
        validate_url!(url)
        events = events.map(&:to_sym)
        validate_events!(events)
        super
      end

      private

      def validate_url!(url)
        raise ArgumentError, "url is required" if url.nil? || url.to_s.strip.empty?
      end

      def validate_events!(events)
        events.each do |event|
          next if VALID_WEBHOOK_EVENTS.include?(event)

          raise ArgumentError,
                "invalid webhook event: #{event}. Must be one of: #{VALID_WEBHOOK_EVENTS.join(", ")}"
        end
      end
    end
  end
end
