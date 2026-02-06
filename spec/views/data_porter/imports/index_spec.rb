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
    view = build_view(imports: imports)
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

  it "includes a new import link" do
    expect(html).to include("New Import")
  end
end
