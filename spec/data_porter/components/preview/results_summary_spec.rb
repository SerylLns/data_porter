# frozen_string_literal: true

RSpec.describe DataPorter::Components::Preview::ResultsSummary do
  def render(component)
    component.call
  end

  let(:report) do
    DataPorter::StoreModels::Report.new(
      imported_count: 42,
      errored_count: 3
    )
  end

  it "renders imported and errored counts" do
    html = render(described_class.new(report: report))

    expect(html).to include("42")
    expect(html).to include("Created")
    expect(html).to include("3")
    expect(html).to include("Errors")
  end

  it "wraps in dp-results container" do
    html = render(described_class.new(report: report))
    expect(html).to include("dp-results")
  end
end
