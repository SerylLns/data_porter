# frozen_string_literal: true

require_relative "sources/base"
require_relative "sources/csv"
require_relative "sources/json"

module DataPorter
  module Sources
    REGISTRY = {
      csv: Csv,
      json: Json
    }.freeze

    def self.resolve(type)
      REGISTRY.fetch(type.to_sym) { raise Error, "Unknown source type: #{type}" }
    end
  end
end
