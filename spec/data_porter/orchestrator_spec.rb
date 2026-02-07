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

  before do
    allow(ActionCable.server).to receive(:broadcast)
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

    it "stores progress in config" do
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      progress = data_import.reload.config["progress"]
      expect(progress).to include("current" => 2, "total" => 2, "percentage" => 100)
    end

    it "broadcasts progress for each record" do
      broadcaster = instance_double(DataPorter::Broadcaster)
      allow(DataPorter::Broadcaster).to receive(:new).and_return(broadcaster)
      allow(broadcaster).to receive(:progress)
      allow(broadcaster).to receive(:success)
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(broadcaster).to have_received(:progress).with(1, 2)
      expect(broadcaster).to have_received(:progress).with(2, 2)
    end

    it "broadcasts success on completion" do
      broadcaster = instance_double(DataPorter::Broadcaster)
      allow(DataPorter::Broadcaster).to receive(:new).and_return(broadcaster)
      allow(broadcaster).to receive(:progress)
      allow(broadcaster).to receive(:success)
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(broadcaster).to have_received(:success).once
    end

    it "broadcasts failure on catastrophic error" do
      data_import.update!(records: [])
      allow(data_import).to receive(:importable_records).and_raise("fatal")
      broadcaster = instance_double(DataPorter::Broadcaster)
      allow(DataPorter::Broadcaster).to receive(:new).and_return(broadcaster)
      allow(broadcaster).to receive(:failure)
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(broadcaster).to have_received(:failure).with("fatal")
    end
  end

  describe "import_params" do
    let(:captured_params) { [] }

    let(:params_target) do
      captured = captured_params
      Class.new(DataPorter::Target) do
        label "ParamGuests"
        model_name "ParamGuest"
        icon "fas fa-users"
        sources :csv

        columns do
          column :name, type: :string
        end

        params do
          param :hotel_id, type: :select, required: true
        end

        define_method(:persist) do |_record, **|
          captured << import_params
        end
      end
    end

    let(:params_import) do
      DataPorter::Registry.register(:param_guests, params_target)
      DataPorter::DataImport.create!(
        target_key: "param_guests",
        source_type: "csv",
        user_type: "User",
        user_id: 1,
        config: { "import_params" => { "hotel_id" => "42" } }
      )
    end

    it "sets import_params on target from config" do
      orchestrator = described_class.new(params_import, content: "name\nAlice\n")
      orchestrator.parse!

      orchestrator = described_class.new(params_import)
      orchestrator.import!

      expect(captured_params.first).to eq("hotel_id" => "42")
    end

    it "defaults to empty hash when config has no import_params" do
      orchestrator = described_class.new(data_import, content: csv_content)
      orchestrator.parse!

      orchestrator = described_class.new(data_import)
      orchestrator.import!

      target = orchestrator.instance_variable_get(:@target)
      expect(target.import_params).to eq({})
    end
  end

  describe "max_records guard" do
    it "fails when record count exceeds max_records" do
      original = DataPorter.configuration.max_records
      DataPorter.configuration.max_records = 1
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.parse!

      expect(data_import.reload.status).to eq("failed")
      expect(data_import.report.error_reports.first.message).to include("exceeds maximum")
    ensure
      DataPorter.configuration.max_records = original
    end

    it "passes when record count is within max_records" do
      original = DataPorter.configuration.max_records
      DataPorter.configuration.max_records = 10
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.parse!

      expect(data_import.reload.status).to eq("previewing")
    ensure
      DataPorter.configuration.max_records = original
    end

    it "skips guard when max_records is nil" do
      original = DataPorter.configuration.max_records
      DataPorter.configuration.max_records = nil
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.parse!

      expect(data_import.reload.status).to eq("previewing")
    ensure
      DataPorter.configuration.max_records = original
    end
  end
end
