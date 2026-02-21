# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/view_test_helper"

RSpec.describe "data_porter/imports/index.html.erb" do
  include ViewTestHelper

  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      icon "fas fa-users"
      model_name "Guest"
    end
  end

  let(:targets) do
    [{ key: :guests, label: "Guests", icon: "fas fa-users", params: [] }]
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

  subject(:html) do
    view = build_view(imports: imports, targets: targets)
    view.render(template: "data_porter/imports/index")
  end

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

  it "includes a new import button" do
    expect(html).to include("New Import")
  end

  it "includes a mapping templates link" do
    expect(html).to include("Mapping Templates")
  end

  it "includes the modal form" do
    expect(html).to include("dp-modal")
    expect(html).to include("<form")
  end

  it "includes the dropzone file input" do
    expect(html).to include("dp-dropzone")
  end

  it "includes the params container target" do
    expect(html).to include("paramsContainer")
  end

  it "includes params data value" do
    expect(html).to include("params-value")
  end

  it "displays the target icon" do
    expect(html).to include('<i class="fas fa-users"></i>')
  end

  context "with no imports" do
    subject(:html) do
      view = build_view(imports: [], targets: targets)
      view.render(template: "data_porter/imports/index")
    end

    it "shows the empty state" do
      expect(html).to include("No imports yet")
    end
  end
end
