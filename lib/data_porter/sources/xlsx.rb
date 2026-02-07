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
        first_row = sheet.simple_rows.first
        first_row&.values&.map(&:to_s) || []
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
        return [] if rows.size <= 1

        headers = rows.first.values.map(&:to_s)
        rows.drop(1).map { |row| build_row(headers, row) }
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
