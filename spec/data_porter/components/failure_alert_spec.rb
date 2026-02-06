# frozen_string_literal: true

RSpec.describe DataPorter::Components::FailureAlert do
  def render(component)
    component.call
  end

  let(:report) do
    r = DataPorter::StoreModels::Report.new
    r.error_reports = [
      DataPorter::StoreModels::Error.new(message: "File not found"),
      DataPorter::StoreModels::Error.new(message: "Invalid format")
    ]
    r
  end

  it "renders error messages" do
    html = render(described_class.new(report: report))

    expect(html).to include("File not found")
    expect(html).to include("Invalid format")
  end

  it "wraps in dp-alert container" do
    html = render(described_class.new(report: report))
    expect(html).to include("dp-alert")
  end
end
