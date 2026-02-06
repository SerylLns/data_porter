# frozen_string_literal: true

require "action_view"

RSpec.describe "data_porter/imports/new.html.erb" do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      icon "fas fa-users"
      model_name "Guest"
    end
  end

  let(:import) { DataPorter::DataImport.new }

  let(:targets) do
    [{ key: :guests, label: "Guests", icon: "fas fa-users" }]
  end

  let(:view) { ActionView::Base.new(lookup_context, assigns, controller) }

  let(:lookup_context) do
    ActionView::LookupContext.new(
      File.expand_path("../../../../app/views", __dir__)
    )
  end

  let(:assigns) { { import: import, targets: targets } }

  let(:controller) do
    instance_double(DataPorter::ImportsController).tap do |c|
      allow(c).to receive(:params).and_return({})
    end
  end

  before do
    routes = DataPorter::Engine.routes
    view.class.include routes.url_helpers
    view.class.default_url_options = { host: "localhost" }
  end

  subject(:html) { view.render(template: "data_porter/imports/new") }

  it "renders a form" do
    expect(html).to include("<form")
  end

  it "includes a target select" do
    expect(html).to include("Guests")
  end

  it "includes a source type select" do
    expect(html).to include("source_type")
  end

  it "includes a file upload field" do
    expect(html).to include('type="file"')
  end

  it "includes a submit button" do
    expect(html).to include('type="submit"')
  end
end
