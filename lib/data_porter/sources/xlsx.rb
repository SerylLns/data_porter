# frozen_string_literal: true

require "creek"
require "tempfile"

module DataPorter
  module Sources
    class Xlsx < Base
      def initialize(data_import, file_path: nil)
        super(data_import)
        @file_path = file_path
      end

      def headers
        sheet = target_sheet
        header = sheet.simple_rows.drop(header_row_index).first
        raw = header&.values&.map(&:to_s) || []
        fallback_headers(raw)
      ensure
        cleanup
      end

      def fetch
        rows = parse_sheet(target_sheet)
        rows.map { |row| apply_csv_mapping(row) }
      ensure
        cleanup
      end

      private

      def target_sheet
        creek = Creek::Book.new(xlsx_path)
        creek.sheets[sheet_index]
      end

      def parse_sheet(sheet)
        rows = sheet.simple_rows.to_a
        offset = header_row_index
        return [] if rows.size <= offset + 1

        headers = extract_headers(rows, offset)
        extract_data_rows(rows, offset, headers)
      end

      def extract_headers(rows, offset)
        rows[offset].values.map(&:to_s)
      end

      def extract_data_rows(rows, offset, headers)
        rows.drop(offset + 1)
            .reject { |row| row.values.all? { |v| v.to_s.strip.empty? } }
            .map { |row| build_row(headers, row) }
      end

      def build_row(headers, row)
        values = row.values.map { |v| v&.to_s }
        headers.zip(values).to_h
      end

      def xlsx_path
        @file_path || download_to_tempfile
      end

      def download_to_tempfile
        @tempfile = Tempfile.new(["data_porter", ".xlsx"])
        @tempfile.binmode
        @tempfile.write(@data_import.file.download)
        @tempfile.rewind
        @tempfile.path
      end

      def sheet_index
        config = @data_import.config
        return 0 unless config.is_a?(Hash)

        config.fetch("sheet_index", 0).to_i
      end

      def cleanup
        return unless @tempfile

        @tempfile.close
        @tempfile.unlink
      end
    end
  end
end
