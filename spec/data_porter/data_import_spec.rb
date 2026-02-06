# frozen_string_literal: true

RSpec.describe DataPorter::DataImport, type: :model do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"
      icon "fas fa-users"
    end
  end

  before do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:guests, target_class)
  end

  describe "validations" do
    it "requires target_key" do
      import = described_class.new(source_type: "csv")

      expect(import).not_to be_valid
      expect(import.errors[:target_key]).to include("can't be blank")
    end

    it "requires source_type" do
      import = described_class.new(target_key: "guests", source_type: nil)

      expect(import).not_to be_valid
      expect(import.errors[:source_type]).to include("can't be blank")
    end

    it "validates source_type inclusion" do
      import = described_class.new(target_key: "guests", source_type: "xml")

      expect(import).not_to be_valid
      expect(import.errors[:source_type]).to include("is not included in the list")
    end

    it "is valid with required attributes" do
      import = described_class.new(
        target_key: "guests",
        source_type: "csv",
        user_type: "User",
        user_id: 1
      )

      expect(import).to be_valid
    end
  end

  describe "enum status" do
    it "defaults to pending" do
      import = described_class.new

      expect(import.status).to eq("pending")
    end

    it "defines all expected statuses" do
      expected = %w[pending parsing previewing importing completed failed dry_running]

      expect(described_class.statuses.keys).to match_array(expected)
    end
  end

  describe "store model attributes" do
    it "defaults records to empty array" do
      import = described_class.new

      expect(import.records).to eq([])
    end

    it "defaults report to a new Report" do
      import = described_class.new

      expect(import.report).to be_a(DataPorter::StoreModels::Report)
    end
  end

  describe "#target_class" do
    it "returns the registered target class" do
      import = described_class.new(target_key: "guests")

      expect(import.target_class).to eq(target_class)
    end

    it "raises TargetNotFound for unknown keys" do
      import = described_class.new(target_key: "unknown")

      expect { import.target_class }.to raise_error(DataPorter::TargetNotFound)
    end
  end

  describe "#previewable?" do
    it "returns true when previewing with records" do
      record = DataPorter::StoreModels::ImportRecord.new(line_number: 1)
      import = described_class.new(status: :previewing, records: [record])

      expect(import).to be_previewable
    end

    it "returns false when not previewing" do
      import = described_class.new(status: :pending)

      expect(import).not_to be_previewable
    end
  end

  describe "#importable_records" do
    it "returns only complete records" do
      complete = DataPorter::StoreModels::ImportRecord.new(line_number: 1, status: "complete")
      partial = DataPorter::StoreModels::ImportRecord.new(line_number: 2, status: "partial")
      import = described_class.new(records: [complete, partial])

      expect(import.importable_records).to eq([complete])
    end
  end

  describe "#records_summary" do
    it "groups records by status" do
      records = [
        DataPorter::StoreModels::ImportRecord.new(line_number: 1, status: "complete"),
        DataPorter::StoreModels::ImportRecord.new(line_number: 2, status: "complete"),
        DataPorter::StoreModels::ImportRecord.new(line_number: 3, status: "partial")
      ]
      import = described_class.new(records: records)

      expect(import.records_summary).to eq("complete" => 2, "partial" => 1)
    end
  end

  describe "persistence" do
    it "saves and reloads with records" do
      import = described_class.create!(
        target_key: "guests",
        source_type: "csv",
        user_type: "User",
        user_id: 1
      )
      record = DataPorter::StoreModels::ImportRecord.new(
        line_number: 1,
        data: { name: "Alice" }
      )
      import.update!(records: [record])

      reloaded = described_class.find(import.id)

      expect(reloaded.records.first.line_number).to eq(1)
      expect(reloaded.records.first.data).to eq({ "name" => "Alice" })
    end
  end
end
