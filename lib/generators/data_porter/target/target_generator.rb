# frozen_string_literal: true

require "rails/generators"

module DataPorter
  module Generators
    class TargetGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :columns, type: :array, default: [], banner: "name:type[:required]"

      def create_target_file
        template("target.rb.tt", "app/importers/#{file_name}_target.rb")
      end

      private

      def target_class_name
        "#{class_name}Target"
      end

      def model_name
        class_name.singularize
      end

      def target_label
        class_name.titleize
      end

      def parsed_columns
        columns.map { |col| parse_column(col) }
      end

      def parse_column(definition)
        parts = definition.split(":")
        {
          name: parts[0],
          type: parts[1] || "string",
          required: parts[2] == "required"
        }
      end
    end
  end
end
