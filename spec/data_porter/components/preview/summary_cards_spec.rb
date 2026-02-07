# frozen_string_literal: true

RSpec.describe DataPorter::Components::Preview::SummaryCards do
  def render(component)
    component.call
  end

  let(:report) do
    DataPorter::StoreModels::Report.new(
      complete_count: 10,
      partial_count: 3,
      missing_count: 2,
      duplicate_count: 1
    )
  end

  it "renders all four count cards" do
    html = render(described_class.new(report: report))

    expect(html).to include("10")
    expect(html).to include("Ready")
    expect(html).to include("3")
    expect(html).to include("Incomplete")
    expect(html).to include("2")
    expect(html).to include("Missing")
    expect(html).to include("1")
    expect(html).to include("Duplicates")
  end

  it "wraps in dp-summary-cards container" do
    html = render(described_class.new(report: report))
    expect(html).to include("dp-summary-cards")
  end
end
