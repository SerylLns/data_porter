# frozen_string_literal: true

require "action_view"
require "action_dispatch"

module ViewTestHelper
  VIEW_CLASS = ActionView::Base.with_empty_template_cache
  VIEW_CLASS.include DataPorter::Engine.routes.url_helpers
  VIEW_CLASS.include Rails.application.routes.url_helpers
  VIEW_CLASS.define_method(:form_authenticity_token) { "test-csrf-token" }

  def build_view(assigns = {})
    lookup = ActionView::LookupContext.new(view_paths)
    ctrl = DataPorter::ImportsController.new
    ctrl.request = ActionDispatch::TestRequest.create
    ctrl.default_url_options = { host: "localhost" }

    view = VIEW_CLASS.new(lookup, assigns, ctrl)
    view.default_url_options = { host: "localhost" }
    view
  end

  def view_paths
    [File.expand_path("../../app/views", __dir__)]
  end
end
