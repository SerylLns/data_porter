# frozen_string_literal: true

module DataPorter
  module Concerns
    module ApplyOptions
      extend ActiveSupport::Concern

      APPLY_OPTIONS = %w[apply_creates apply_updates].freeze

      private

      def store_apply_options
        return unless @import.target_class._match_keys

        options = APPLY_OPTIONS.index_with { |key| ActiveModel::Type::Boolean.new.cast(params[key]) != false }
        @import.update!(config: (@import.config || {}).merge(options))
      end
    end
  end
end
