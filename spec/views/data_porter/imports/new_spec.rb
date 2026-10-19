# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/view_test_helper"

RSpec.describe "data_porter/imports/new.html.erb" do
  include ViewTestHelper

  let(:import) { DataPorter::DataImport.new }

  let(:targets) do
    [{ key: :guests, label: "Guests", icon: "fas fa-users", params: [], header_row: 3 }]
  end

  subject(:html) do
    view = build_view(import: import, targets: targets)
    view.render(template: "data_porter/imports/new")
  end

  it "renders a form" do
    expect(html).to include("<form")
  end

  it "includes a target select" do
    expect(html).to include("Guests")
  end

  it "includes a source type select" do
    expect(html).to include("source_type")
  end

  it "includes the dropzone file input" do
    expect(html).to include("dp-dropzone")
    expect(html).to include('type="file"')
  end

  it "includes a submit button" do
    expect(html).to include('type="submit"')
  end

  it "includes the params container" do
    expect(html).to include("dp-params-container")
  end

  it "includes params data attribute" do
    expect(html).to include("data-params=")
  end

  it "includes the header row field" do
    expect(html).to include('name="data_import[header_row]"')
  end

  it "includes per-target header row defaults" do
    expect(html).to include("data-header-rows=")
    expect(html).to include("&quot;guests&quot;:3")
  end

  context "with errors" do
    let(:import) do
      i = DataPorter::DataImport.new
      i.errors.add(:file, "must be attached for CSV imports")
      i
    end

    it "renders error messages" do
      expect(html).to include("dp-alert--danger")
      expect(html).to include("must be attached for CSV imports")
    end
  end
end
