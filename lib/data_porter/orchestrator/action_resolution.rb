# frozen_string_literal: true

module DataPorter
  class Orchestrator
    module ActionResolution
      private

      def resolve_actions(records)
        return records unless @target.class._match_keys

        RecordActionResolver.new(@target).call(records)
      end

      def action_counts
        actions = @data_import.records.group_by(&:action).transform_values(&:count)
        {
          create_count: actions["create"] || 0,
          update_count: actions["update"] || 0,
          unchanged_count: actions["unchanged"] || 0
        }
      end
    end
  end
end
