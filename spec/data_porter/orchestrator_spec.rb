# frozen_string_literal: true

RSpec.describe DataPorter::Orchestrator do
  let(:persisted_records) { [] }

  let(:target_class) do
    records = persisted_records
    Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"
      icon "fas fa-users"
      sources :csv

      columns do
        column :first_name, type: :string, required: true
        column :last_name, type: :string
        column :email, type: :email
      end

      csv_mapping do
        map "First Name" => :first_name
        map "Last Name" => :last_name
        map "Email" => :email
      end

      define_method(:persist) do |record, **|
        records << record.data
      end
    end
  end

  let(:data_import) do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:guests, target_class)
    DataPorter::DataImport.create!(
      target_key: "guests",
      source_type: "csv",
      user_type: "User",
      user_id: 1
    )
  end

  let(:csv_content) do
    "First Name,Last Name,Email\nAlice,Smith,alice@example.com\nBob,Jones,bob@example.com\n"
  end

  describe "#parse!" do
    it "transitions to previewing" do
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.parse!

      expect(data_import.reload.status).to eq("previewing")
    end

    it "creates import records from source data" do
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.parse!

      expect(data_import.reload.records.size).to eq(2)
    end

    it "populates record data from columns" do
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.parse!

      record = data_import.reload.records.first
      expect(record.data["first_name"]).to eq("Alice")
      expect(record.data["email"]).to eq("alice@example.com")
    end

    it "sets line numbers" do
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.parse!

      records = data_import.reload.records
      expect(records.map(&:line_number)).to eq([1, 2])
    end

    it "validates required fields" do
      csv = "First Name,Last Name,Email\n,Smith,alice@example.com\n"
      orchestrator = described_class.new(data_import, content: csv)

      orchestrator.parse!

      record = data_import.reload.records.first
      expect(record.status).to eq("missing")
    end

    it "validates type constraints" do
      csv = "First Name,Last Name,Email\nAlice,Smith,not-an-email\n"
      orchestrator = described_class.new(data_import, content: csv)

      orchestrator.parse!

      record = data_import.reload.records.first
      expect(record.status).to eq("partial")
    end

    it "builds a report" do
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.parse!

      report = data_import.reload.report
      expect(report.records_count).to eq(2)
      expect(report.complete_count).to eq(2)
    end

    it "transitions to failed on error" do
      allow_any_instance_of(DataPorter::Sources::Csv).to receive(:fetch).and_raise("parse error")
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.parse!

      expect(data_import.reload.status).to eq("failed")
    end
  end

  describe "#extract_headers!" do
    it "transitions to mapping" do
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.extract_headers!

      expect(data_import.reload.status).to eq("mapping")
    end

    it "stores file_headers in config" do
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.extract_headers!

      expect(data_import.reload.config["file_headers"]).to eq(["First Name", "Last Name", "Email"])
    end

    it "transitions to failed on error" do
      allow_any_instance_of(DataPorter::Sources::Csv).to receive(:headers).and_raise("read error")
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.extract_headers!

      expect(data_import.reload.status).to eq("failed")
    end
  end

  describe "#import!" do
    before do
      orchestrator = described_class.new(data_import, content: csv_content)
      orchestrator.parse!
    end

    it "transitions to completed" do
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(data_import.reload.status).to eq("completed")
    end

    it "calls persist for each importable record" do
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(persisted_records.size).to eq(2)
    end

    it "passes record data to persist" do
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(persisted_records.first).to include("first_name" => "Alice")
    end

    it "handles per-record errors" do
      error_target = Class.new(DataPorter::Target) do
        label "Failing"
        model_name "Failing"
        columns do
          column :name, type: :string
        end

        def persist(_record, **)
          raise "DB error"
        end
      end

      DataPorter::Registry.register(:failing, error_target)
      import = DataPorter::DataImport.create!(
        target_key: "failing",
        source_type: "csv",
        user_type: "User",
        user_id: 1
      )
      orchestrator = described_class.new(import, content: "name\nAlice\n")
      orchestrator.parse!

      orchestrator = described_class.new(import)
      orchestrator.import!

      expect(import.reload.status).to eq("completed")
      expect(import.report.errored_count).to eq(1)
    end

    it "updates report counts" do
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      report = data_import.reload.report
      expect(report.imported_count).to eq(2)
    end

    it "transitions to failed on catastrophic error" do
      data_import.update!(records: [])
      allow(data_import).to receive(:importable_records).and_raise("fatal")
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(data_import.reload.status).to eq("failed")
    end
  end
end
