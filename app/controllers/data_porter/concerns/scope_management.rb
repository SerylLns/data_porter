# frozen_string_literal: true

module DataPorter
  module Concerns
    module ScopeManagement
      private

      def resolve_owner
        return unless respond_to?(:current_user, true)
        return unless current_user

        scope = DataPorter.configuration.scope
        scope ? scope.call(current_user) : current_user
      end
    end
  end
end
