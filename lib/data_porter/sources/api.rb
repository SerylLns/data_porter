# frozen_string_literal: true

require "net/http"
require "json"

module DataPorter
  module Sources
    class Api < Base
      def fetch
        api = @target_class._api_config
        response = perform_request(api)
        parsed = ::JSON.parse(response.body)
        records = extract_records(parsed, api)

        Array(records).map do |hash|
          hash.transform_keys { |k| k.parameterize(separator: "_") }
        end
      end

      private

      def perform_request(api)
        url = resolve_endpoint(api)
        headers = resolve_headers(api)
        uri = URI(url)

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          request = Net::HTTP::Get.new(uri)
          headers.each { |k, v| request[k] = v }
          http.request(request)
        end
      end

      def resolve_endpoint(api)
        params = @data_import.config.symbolize_keys
        api.endpoint.is_a?(Proc) ? api.endpoint.call(params) : api.endpoint
      end

      def resolve_headers(api)
        api.headers.is_a?(Proc) ? api.headers.call : (api.headers || {})
      end

      def extract_records(parsed, api)
        root = api.response_root
        root ? parsed[root.to_s] : parsed
      end
    end
  end
end
