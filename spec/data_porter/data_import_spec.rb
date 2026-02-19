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
      expected = %w[pending parsing previewing importing completed failed dry_running extracting_headers mapping]

      expect(described_class.statuses.keys).to match_array(expected)
    end
  end

  describe "#file_based?" do
    it "returns true for csv source type" do
      import = described_class.new(source_type: "csv")
      expect(import.file_based?).to be true
    end

    it "returns true for xlsx source type" do
      import = described_class.new(source_type: "xlsx")
      expect(import.file_based?).to be true
    end

    it "returns false for json source type" do
      import = described_class.new(source_type: "json")
      expect(import.file_based?).to be false
    end

    it "returns false for api source type" do
      import = described_class.new(source_type: "api")
      expect(import.file_based?).to be false
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

  describe "#reset_to_mapping!" do
    it "sets status to mapping" do
      import = described_class.create!(target_key: "guests", source_type: "csv", status: :previewing)

      import.reset_to_mapping!

      expect(import.status).to eq("mapping")
    end

    it "clears records" do
      record = DataPorter::StoreModels::ImportRecord.new(line_number: 1, data: { name: "Alice" })
      import = described_class.create!(target_key: "guests", source_type: "csv", status: :previewing, records: [record])

      import.reset_to_mapping!

      expect(import.records).to eq([])
    end

    it "resets report" do
      report = DataPorter::StoreModels::Report.new(records_count: 5, complete_count: 3)
      import = described_class.create!(target_key: "guests", source_type: "csv", status: :previewing, report: report)

      import.reset_to_mapping!

      expect(import.report.records_count).to eq(0)
      expect(import.report.complete_count).to eq(0)
    end

    it "clears config progress" do
      import = described_class.create!(
        target_key: "guests", source_type: "csv", status: :previewing,
        config: { "progress" => { "current" => 10, "total" => 100 }, "file_headers" => %w[A B] }
      )

      import.reset_to_mapping!

      expect(import.config).not_to have_key("progress")
    end

    it "preserves file_headers in config" do
      import = described_class.create!(
        target_key: "guests", source_type: "csv", status: :previewing,
        config: { "file_headers" => %w[Name Email], "progress" => { "current" => 5 } }
      )

      import.reset_to_mapping!

      expect(import.config["file_headers"]).to eq(%w[Name Email])
    end

    it "preserves column_mapping in config" do
      import = described_class.create!(
        target_key: "guests", source_type: "csv", status: :previewing,
        config: { "column_mapping" => { "Name" => "name" }, "progress" => {} }
      )

      import.reset_to_mapping!

      expect(import.config["column_mapping"]).to eq("Name" => "name")
    end
  end

  describe "file attachment" do
    it "responds to file" do
      import = described_class.new

      expect(import).to respond_to(:file)
    end
  end

  describe ".purgeable" do
    it "returns imports older than purge_after with terminal status" do
      old_completed = described_class.create!(
        target_key: "guests", source_type: "csv", status: :completed,
        created_at: 61.days.ago
      )
      old_failed = described_class.create!(
        target_key: "guests", source_type: "csv", status: :failed,
        created_at: 90.days.ago
      )
      recent_completed = described_class.create!(
        target_key: "guests", source_type: "csv", status: :completed,
        created_at: 10.days.ago
      )
      old_pending = described_class.create!(
        target_key: "guests", source_type: "csv", status: :pending,
        created_at: 90.days.ago
      )

      result = described_class.purgeable

      expect(result).to include(old_completed, old_failed)
      expect(result).not_to include(recent_completed, old_pending)
    end

    it "respects custom purge_after configuration" do
      allow(DataPorter.configuration).to receive(:purge_after).and_return(30.days)

      old = described_class.create!(
        target_key: "guests", source_type: "csv", status: :completed,
        created_at: 31.days.ago
      )

      expect(described_class.purgeable).to include(old)
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
