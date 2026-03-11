# frozen_string_literal: true

require "store_model"
require_relative "error"

module DataPorter
  module StoreModels
    class ImportRecord
      include StoreModel::Model

      attribute :line_number, :integer
      attribute :status, :string, default: "pending"
      attribute :data, default: -> { HashWithIndifferentAccess.new }
      attribute :errors_list, Error.to_array_type, default: -> { [] }

      def data=(value)
        super(value.is_a?(Hash) ? value.with_indifferent_access : value)
      end
      attribute :warnings, Error.to_array_type, default: -> { [] }
      attribute :target_id, :integer
      attribute :dry_run_passed, :boolean, default: false

      def complete? = status == "complete"

      def importable? = status == "complete"

      def add_error(message)
        errors_list << Error.new(message: message)
      end

      def add_warning(message)
        warnings << Error.new(message: message)
      end

      def attributes
        data.stringify_keys.compact.with_indifferent_access
      end

      def determine_status!
        self.status = if required_error?
                        "missing"
                      elsif errors_list.any?
                        "partial"
                      else
                        "complete"
                      end
      end

      private

      def required_error?
        errors_list.any? { |e| e.message.include?("required") }
      end
    end
  end
end
