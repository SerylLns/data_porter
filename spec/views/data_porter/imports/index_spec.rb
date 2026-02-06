# frozen_string_literal: true

require "action_view"

RSpec.describe "data_porter/imports/index.html.erb" do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      icon "fas fa-users"
      model_name "Guest"
    end
  end

  let(:imports) do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:guests, target_class)

    [
      DataPorter::DataImport.create!(
        target_key: "guests",
        source_type: "csv",
        status: :completed
      ),
      DataPorter::DataImport.create!(
        target_key: "guests",
        source_type: "json",
        status: :pending
      )
    ]
  end

  let(:view) { ActionView::Base.new(lookup_context, assigns, controller) }

  let(:lookup_context) do
    ActionView::LookupContext.new(
      File.expand_path("../../../../app/views", __dir__)
    )
  end

  let(:assigns) { { imports: imports } }

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

  subject(:html) { view.render(template: "data_porter/imports/index") }

  it "renders the imports table" do
    expect(html).to include("<table")
  end

  it "shows the target key for each import" do
    expect(html).to include("guests")
  end

  it "shows the source type" do
    expect(html).to include("csv")
    expect(html).to include("json")
  end

  it "shows status for each import" do
    expect(html).to include("completed")
    expect(html).to include("pending")
  end

  it "includes a new import link" do
    expect(html).to include("New Import")
  end
end
