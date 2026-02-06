# frozen_string_literal: true

RSpec.describe DataPorter::Sources do
  describe ".resolve" do
    it "returns Csv for csv type" do
      expect(described_class.resolve("csv")).to eq(DataPorter::Sources::Csv)
    end

    it "accepts symbol keys" do
      expect(described_class.resolve(:csv)).to eq(DataPorter::Sources::Csv)
    end

    it "raises for unknown source types" do
      expect { described_class.resolve(:xml) }.to raise_error(DataPorter::Error, /Unknown source/)
    end
  end
end
