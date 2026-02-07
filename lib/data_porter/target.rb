# frozen_string_literal: true

require_relative "dsl/column"
require_relative "dsl/param"
require_relative "dsl/api_config"

module DataPorter
  class Target
    class << self
      attr_reader :_label, :_model_name, :_icon, :_sources,
                  :_columns, :_csv_mappings, :_dedup_keys, :_json_root,
                  :_api_config, :_dry_run_enabled, :_params

      def label(value)
        @_label = value
        auto_register
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

      def api_config(&)
        @_api_config = DSL::ApiConfig.new
        @_api_config.instance_eval(&)
      end

      def dry_run_enabled
        @_dry_run_enabled = true
      end

      def params(&)
        @_params = []
        instance_eval(&)
      end

      def param(name, **)
        @_params << DSL::Param.new(name: name, **)
      end

      private

      def auto_register
        return unless name

        key = name.demodulize.delete_suffix("Target").underscore
        Registry.register(key, self)
      end
    end

    attr_accessor :import_params

    def initialize
      @import_params = {}
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
