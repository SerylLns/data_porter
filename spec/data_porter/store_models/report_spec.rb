# frozen_string_literal: true

RSpec.describe DataPorter::StoreModels::Report do
  subject(:report) { described_class.new }

  it "defaults records_count to 0" do
    expect(report.records_count).to eq(0)
  end

  it "defaults complete_count to 0" do
    expect(report.complete_count).to eq(0)
  end

  it "defaults partial_count to 0" do
    expect(report.partial_count).to eq(0)
  end

  it "defaults missing_count to 0" do
    expect(report.missing_count).to eq(0)
  end

  it "defaults action counts to 0" do
    expect([report.create_count, report.update_count, report.unchanged_count]).to eq([0, 0, 0])
  end

  it "defaults excluded_count to 0" do
    expect(report.excluded_count).to eq(0)
  end

  describe "#preview_counts" do
    it "returns the counts refreshed by the preview" do
      report = described_class.new(complete_count: 2, create_count: 1, excluded_count: 1)

      expect(report.preview_counts).to eq(
        complete_count: 2, partial_count: 0, missing_count: 0,
        create_count: 1, update_count: 0, unchanged_count: 0, excluded_count: 1
      )
    end
  end

  it "defaults duplicate_count to 0" do
    expect(report.duplicate_count).to eq(0)
  end

  it "defaults imported_count to 0" do
    expect(report.imported_count).to eq(0)
  end

  it "defaults errored_count to 0" do
    expect(report.errored_count).to eq(0)
  end

  it "defaults error_reports to empty array" do
    expect(report.error_reports).to eq([])
  end

  it "accepts error_reports as Error instances" do
    error = DataPorter::StoreModels::Error.new(message: "boom")
    report = described_class.new(error_reports: [error])

    expect(report.error_reports.first.message).to eq("boom")
  end
end
