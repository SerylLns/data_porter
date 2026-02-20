# frozen_string_literal: true

require "net/http"
require "openssl"

module DataPorter
  class WebhookJob < ActiveJob::Base
    queue_as { DataPorter.configuration.queue_name }

    def perform(url, payload_json, headers = {})
      uri = URI.parse(url)
      request = build_request(uri, payload_json, headers)
      execute_request(uri, request)
    end

    private

    def build_request(uri, payload_json, headers)
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      headers.each { |key, value| request[key] = value }
      sign_request(request, payload_json)
      request.body = payload_json
      request
    end

    def sign_request(request, payload_json)
      secret = DataPorter.configuration.webhook_secret
      return unless secret

      digest = OpenSSL::HMAC.hexdigest("SHA256", secret, payload_json)
      request["X-DataPorter-Signature"] = "sha256=#{digest}"
    end

    def execute_request(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 10
      http.request(request)
    rescue StandardError => e
      Rails.logger.error("[DataPorter] Webhook delivery failed: #{e.message}")
    end
  end
end
