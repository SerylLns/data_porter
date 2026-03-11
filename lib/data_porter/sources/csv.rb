# frozen_string_literal: true

require "csv"

module DataPorter
  module Sources
    class Csv < Base
      SEPARATORS = [",", ";", "\t"].freeze

      def initialize(data_import, content: nil)
        super(data_import)
        @content = content
      end

      def headers
        line = csv_content.lines[header_row_index]
        raw = ::CSV.parse_line(line, **extra_options).map(&:to_s)
        fallback_headers(raw)
      end

      def fetch
        rows = []
        ::CSV.parse(effective_csv_content, **csv_options) do |row|
          next if row.to_h.values.all? { |v| v.to_s.strip.empty? }

          rows << apply_csv_mapping(row)
        end
        rows
      end

      private

      def csv_content
        @csv_content ||= ensure_utf8(@content || download_file)
      end

      def effective_csv_content
        offset = header_row_index
        return csv_content if offset.zero?

        csv_content.lines.drop(offset).join
      end

      def download_file
        @data_import.file.download
      end

      def ensure_utf8(raw)
        raw = strip_bom(raw)
        return raw if raw.encoding == Encoding::UTF_8 && raw.valid_encoding?

        raw.force_encoding("UTF-8")
        return raw if raw.valid_encoding?

        raw.encode("UTF-8", "ISO-8859-1")
      end

      def strip_bom(raw)
        bytes = raw.b
        return raw unless bytes.start_with?("\xEF\xBB\xBF".b)

        bytes[3..].force_encoding("UTF-8")
      end

      def csv_options
        { headers: true }.merge(extra_options)
      end

      def extra_options
        config = @data_import.config
        return { col_sep: detect_separator } unless config.is_a?(Hash)

        opts = config.symbolize_keys.slice(:col_sep, :encoding)
        opts[:col_sep] ||= detect_separator
        opts
      end

      def detect_separator
        header_line = csv_content.lines[header_row_index].to_s
        SEPARATORS.max_by { |sep| header_line.count(sep) }
      end
    end
  end
end
