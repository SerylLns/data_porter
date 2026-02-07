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
    expect(html).to include("Imported")
    expect(html).to include("3")
    expect(html).to include("Errors")
  end

  it "wraps in dp-results container" do
    html = render(described_class.new(report: report))
    expect(html).to include("dp-results")
  end

  it "shows success state when no errors" do
    success_report = DataPorter::StoreModels::Report.new(imported_count: 10, errored_count: 0)
    html = render(described_class.new(report: success_report))

    expect(html).to include("dp-results--success")
    expect(html).to include("Import completed")
  end

  it "shows partial state when errors exist" do
    html = render(described_class.new(report: report))

    expect(html).to include("dp-results--partial")
    expect(html).to include("Import completed with errors")
  end

  it "renders duration when provided" do
    html = render(described_class.new(report: report, duration: "about 2 minutes"))

    expect(html).to include("Duration: about 2 minutes")
  end
end
