# frozen_string_literal: true

module DataPorter
  module DSL
    Column = Struct.new(:name, :type, :required, :label, :transform, :synonyms, :options, keyword_init: true) do
      def initialize(name:, type: :string, required: false, label: nil, transform: [], synonyms: [], **options)
        super(
          name: name.to_sym,
          type: type.to_sym,
          required: required,
          label: label || name.to_s.humanize,
          transform: Array(transform),
          synonyms: Array(synonyms),
          options: options
        )
      end
    end
  end
end
