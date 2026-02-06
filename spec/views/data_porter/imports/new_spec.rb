# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/view_test_helper"

RSpec.describe "data_porter/imports/new.html.erb" do
  include ViewTestHelper

  let(:import) { DataPorter::DataImport.new }

  let(:targets) do
    [{ key: :guests, label: "Guests", icon: "fas fa-users" }]
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

  it "includes a file upload field" do
    expect(html).to include('type="file"')
  end

  it "includes a submit button" do
    expect(html).to include('type="submit"')
  end
end
