# frozen_string_literal: true

require "csv"

module DataPorter
  module Sources
    class Csv < Base
      def initialize(data_import, content: nil)
        super(data_import)
        @content = content
      end

      def headers
        first_line = csv_content.lines.first
        raw = ::CSV.parse_line(first_line, **extra_options).map(&:to_s)
        fallback_headers(raw)
      end

      def fetch
        rows = []
        ::CSV.parse(csv_content, **csv_options) do |row|
          rows << apply_csv_mapping(row)
        end
        rows
      end

      private

      def csv_content
        @content || download_file
      end

      def download_file
        @data_import.file.download.force_encoding("UTF-8")
      end

      def csv_options
        { headers: true }.merge(extra_options)
      end

      def extra_options
        config = @data_import.config
        return {} unless config.is_a?(Hash)

        config.symbolize_keys.slice(:col_sep, :encoding)
      end
    end
  end
end
