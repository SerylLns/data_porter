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

  it "renders skipped count when records were skipped" do
    skip_report = DataPorter::StoreModels::Report.new(
      imported_count: 5, errored_count: 0, missing_count: 1, partial_count: 1
    )
    html = render(described_class.new(report: skip_report))

    expect(html).to include("2")
    expect(html).to include("Skipped")
  end

  it "does not render skipped card when no records were skipped" do
    clean_report = DataPorter::StoreModels::Report.new(imported_count: 5, errored_count: 0)
    html = render(described_class.new(report: clean_report))

    expect(html).not_to include("Skipped")
  end

  it "shows partial state when records were skipped" do
    skip_report = DataPorter::StoreModels::Report.new(
      imported_count: 5, errored_count: 0, missing_count: 1, partial_count: 0
    )
    html = render(described_class.new(report: skip_report))

    expect(html).to include("dp-results--partial")
  end

  context "when update_mode: true" do
    let(:update_report) do
      DataPorter::StoreModels::Report.new(imported_count: 7, updated_count: 4, skipped_count: 5, errored_count: 0)
    end
    let(:doc) { Nokogiri::HTML(render(described_class.new(report: update_report, update_mode: true))) }

    def stat(css)
      doc.at_css(".#{css}")&.text
    end

    it "labels created records as created" do
      expect(stat("dp-results__stat--success")).to eq("7Created")
    end

    it "renders the updated count" do
      expect(stat("dp-results__stat--updated")).to eq("4Updated")
    end

    it "renders records left untouched" do
      expect(stat("dp-results__stat--untouched")).to eq("5Left untouched")
    end
  end

  context "when update_mode: false (default)" do
    it "does not render update mode stats" do
      html = render(described_class.new(report: report))

      expect(html).not_to include("dp-results__stat--updated")
      expect(html).not_to include("dp-results__stat--untouched")
    end
  end
end
