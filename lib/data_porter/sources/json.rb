# frozen_string_literal: true

require "json"

module DataPorter
  module Sources
    class Json < Base
      def initialize(data_import, content: nil)
        super(data_import)
        @content = content
      end

      def fetch
        parsed = ::JSON.parse(json_content)
        records = extract_records(parsed)

        Array(records).map do |hash|
          hash.transform_keys { |k| k.parameterize(separator: "_").to_sym }
        end
      end

      private

      def json_content
        @content || config_raw_json || download_file
      end

      def config_raw_json
        config = @data_import.config
        config["raw_json"] if config.is_a?(Hash)
      end

      def download_file
        @data_import.file.download
      end

      def extract_records(parsed)
        root = @target_class._json_root
        return parsed unless root

        parsed.dig(*root.split("."))
      end
    end
  end
end
