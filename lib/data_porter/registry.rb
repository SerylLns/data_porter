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
        @targets.map do |key, klass|
          { key: key, label: klass._label, icon: klass._icon }
        end
      end

      def refresh!
        clear
      end

      def clear
        @targets = {}
      end
    end
  end
end
