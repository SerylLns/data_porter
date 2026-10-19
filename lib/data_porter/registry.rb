# frozen_string_literal: true

module DataPorter
  class TargetNotFound < Error; end

  module Registry
    @targets = {}

    class << self
      def register(key, klass)
        @targets[key.to_sym] = klass
      end

      def find(key)
        @targets.fetch(key.to_sym) { raise TargetNotFound, "Target '#{key}' not found" }
      end

      def available
        @targets.map { |key, klass| serialize_target(key, klass) }
      end

      def refresh!
        clear
      end

      def clear
        @targets = {}
      end

      private

      def serialize_target(key, klass)
        {
          key: key,
          label: klass._label,
          icon: klass._icon,
          sources: klass._sources || DataPorter.configuration.enabled_sources,
          params: serialize_params(klass._params),
          header_row: (klass._header_row || 0) + 1
        }
      end

      def resolve_collection(collection)
        return unless collection

        collection.respond_to?(:call) ? collection.call : collection
      end

      def serialize_params(params)
        return [] unless params

        params.map { |p| serialize_param(p) }
      end

      def serialize_param(param)
        {
          name: param.name,
          type: param.type,
          required: param.required,
          label: param.label,
          default: param.default,
          collection: resolve_collection(param.collection)
        }.compact
      end
    end
  end
end
