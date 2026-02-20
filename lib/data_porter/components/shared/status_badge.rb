# frozen_string_literal: true

module DataPorter
  module Components
    module Shared
      class StatusBadge < Base
        def initialize(status:)
          super()
          @status = status.to_s
        end

        def view_template
          span(class: "dp-badge dp-badge--#{@status}") do
            I18n.t("data_porter.components.status_badge.#{@status}", default: @status.capitalize)
          end
        end
      end
    end
  end
end
