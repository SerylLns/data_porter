# frozen_string_literal: true

require "csv"

module DataPorter
  class RejectsCsvBuilder
    def initialize(columns, records)
      @columns = columns
      @records = records
    end

    def generate
      CSV.generate do |csv|
        csv << header_row
        rejected_records.each { |r| csv << record_row(r) }
      end
    end

    private

    def header_row
      ["line"] + @columns.map { |c| c.name.to_s } + ["errors"]
    end

    def rejected_records
      @records.reject(&:complete?)
    end

    def record_row(record)
      values = @columns.map { |c| record.data[c.name.to_s] }
      errors = record.errors_list.map(&:message).join("; ")
      [record.line_number] + values + [errors]
    end
  end
end
