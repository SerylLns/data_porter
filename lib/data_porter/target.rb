# frozen_string_literal: true

require_relative "dsl/column"

module DataPorter
  class Target
    class << self
      attr_reader :_label, :_model_name, :_icon, :_sources,
                  :_columns, :_csv_mappings, :_dedup_keys, :_json_root

      def label(value)
        @_label = value
      end

      def model_name(value)
        @_model_name = value
      end

      def icon(value)
        @_icon = value
      end

      def sources(*types)
        @_sources = types.map(&:to_sym)
      end

      def columns(&)
        @_columns = []
        instance_eval(&)
      end

      def column(name, **)
        @_columns << DSL::Column.new(name: name, **)
      end

      def csv_mapping(&)
        @_csv_mappings = {}
        instance_eval(&)
      end

      def map(hash)
        @_csv_mappings.merge!(hash)
      end

      def deduplicate_by(*keys)
        @_dedup_keys = keys.map(&:to_sym)
      end

      def json_root(path)
        @_json_root = path
      end
    end

    def transform(record)
      record
    end

    def validate(record); end

    def persist(_record, context:)
      raise NotImplementedError
    end

    def after_import(_results, context:); end

    def on_error(_record, _error, context:); end
  end
end
