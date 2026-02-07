# frozen_string_literal: true

module DataPorter
  module DSL
    VALID_PARAM_TYPES = %i[select text number hidden].freeze

    Param = Struct.new(:name, :type, :required, :label, :collection, :default, :options, keyword_init: true) do
      def initialize(**attrs)
        validate_type!(attrs[:type] || :text)
        extra = attrs.except(:name, :type, :required, :label, :collection, :default, :options)
        apply_defaults!(attrs, extra)
        super(**attrs.slice(:name, :type, :required, :label, :collection, :default, :options))
      end

      private

      def apply_defaults!(attrs, extra)
        attrs[:name] = attrs[:name].to_sym
        attrs[:type] = (attrs[:type] || :text).to_sym
        attrs[:required] = attrs.fetch(:required, false)
        attrs[:label] ||= attrs[:name].to_s.humanize
        attrs[:options] = extra
      end

      def validate_type!(type)
        return if VALID_PARAM_TYPES.include?(type.to_sym)

        raise ArgumentError, "invalid param type: #{type}. Must be one of: #{VALID_PARAM_TYPES.join(", ")}"
      end
    end
  end
end
