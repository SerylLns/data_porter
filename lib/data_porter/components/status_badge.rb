# frozen_string_literal: true

module DataPorter
  module Components
    class StatusBadge < Base
      def initialize(status:)
        super()
        @status = status.to_s
      end

      def view_template
        span(class: "dp-badge dp-badge--#{@status}") { @status.capitalize }
      end
    end
  end
end
