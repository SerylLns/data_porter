# frozen_string_literal: true

module DataPorter
  module DSL
    class ApiConfig
      def endpoint(value = nil)
        return @endpoint if value.nil?

        @endpoint = value
      end

      def headers(value = nil)
        return @headers if value.nil?

        @headers = value
      end

      def response_root(value = nil)
        return @response_root if value.nil?

        @response_root = value
      end
    end
  end
end
