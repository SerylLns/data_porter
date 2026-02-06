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
