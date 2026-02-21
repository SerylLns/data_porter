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

    it "clears stale checkpoint from previous import" do
      data_import.update!(config: {
                            "checkpoint" => { "processed" => 5, "created" => 4, "errored" => 1 },
                            "progress" => { "current" => 5, "total" => 10 }
                          })
      orchestrator = described_class.new(data_import, content: csv_content)

      orchestrator.parse!

      config = data_import.reload.config
      expect(config).not_to have_key("checkpoint")
      expect(config).not_to have_key("progress")
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

    it "preserves existing report data on failure" do
      orchestrator = described_class.new(data_import)
      allow(data_import).to receive(:importable_records).and_raise("fatal")

      orchestrator.import!

      report = data_import.reload.report
      expect(report.records_count).to eq(2)
      expect(report.complete_count).to eq(2)
      expect(report.error_reports.first.message).to eq("fatal")
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

    it "preserves checkpoint in config on catastrophic failure" do
      data_import.update!(config: {
                            "checkpoint" => { "processed" => 1, "created" => 1, "errored" => 0 }
                          })
      allow(data_import).to receive(:importable_records).and_raise("fatal")
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      checkpoint = data_import.reload.config["checkpoint"]
      expect(checkpoint["processed"]).to eq(1)
    end

    it "clears checkpoint after successful import" do
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(data_import.reload.config).not_to have_key("checkpoint")
    end

    it "resumes from checkpoint skipping already-processed records" do
      data_import.update!(config: {
                            "checkpoint" => { "processed" => 1, "created" => 1, "errored" => 0 }
                          })
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(persisted_records.size).to eq(1)
      expect(persisted_records.first).to include("first_name" => "Bob")
    end

    it "seeds results from checkpoint counts" do
      data_import.update!(config: {
                            "checkpoint" => { "processed" => 1, "created" => 1, "errored" => 0 }
                          })
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      report = data_import.reload.report
      expect(report.imported_count).to eq(2)
    end

    it "processes all records when no checkpoint exists" do
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(persisted_records.size).to eq(2)
    end

    it "does not save checkpoint during parse" do
      fresh_import = DataPorter::DataImport.create!(
        target_key: "guests", source_type: "csv",
        user_type: "User", user_id: 1
      )
      orchestrator = described_class.new(fresh_import, content: csv_content)

      orchestrator.parse!

      expect(fresh_import.reload.config).not_to have_key("checkpoint")
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

  describe "column transformers" do
    let(:transformer_target) do
      Class.new(DataPorter::Target) do
        label "TransformerGuests"
        model_name "TransformerGuest"
        sources :csv

        columns do
          column :email, type: :email, transform: %i[strip downcase]
          column :phone, type: :phone, transform: %i[strip normalize_phone]
          column :name, type: :string
        end
      end
    end

    let(:transformer_import) do
      DataPorter::Registry.register(:transformer_guests, transformer_target)
      DataPorter::DataImport.create!(
        target_key: "transformer_guests",
        source_type: "csv",
        user_type: "User",
        user_id: 1
      )
    end

    it "applies column transformers during parse" do
      csv = "email,phone,name\n  ALICE@EXAMPLE.COM  , +1 (555) 123-4567 ,Alice\n"
      orchestrator = described_class.new(transformer_import, content: csv)

      orchestrator.parse!

      record = transformer_import.reload.records.first
      expect(record.data["email"]).to eq("alice@example.com")
      expect(record.data["phone"]).to eq("+15551234567")
    end

    it "leaves untransformed columns unchanged" do
      csv = "email,phone,name\n  ALICE@EXAMPLE.COM  , +1 (555) 123-4567 ,Alice\n"
      orchestrator = described_class.new(transformer_import, content: csv)

      orchestrator.parse!

      record = transformer_import.reload.records.first
      expect(record.data["name"]).to eq("Alice")
    end

    it "applies transformers before target.transform" do
      order = []
      target_with_tracking = Class.new(DataPorter::Target) do
        label "Tracking"
        model_name "Tracking"
        sources :csv

        columns do
          column :email, type: :string, transform: [:downcase]
        end

        define_method(:transform) do |record|
          order << record.data[:email]
          super(record)
        end
      end

      DataPorter::Registry.register(:tracking, target_with_tracking)
      import = DataPorter::DataImport.create!(
        target_key: "tracking",
        source_type: "csv",
        user_type: "User",
        user_id: 1
      )
      orchestrator = described_class.new(import, content: "email\nALICE@EXAMPLE.COM\n")

      orchestrator.parse!

      expect(order).to eq(["alice@example.com"])
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

  describe "transaction_mode :all" do
    let(:persisted_names) { [] }

    let(:all_or_nothing_target) do
      names = persisted_names
      Class.new(DataPorter::Target) do
        label "AllOrNothing"
        model_name "AllOrNothing"
        sources :csv

        columns do
          column :name, type: :string
        end

        define_method(:persist) do |record, **|
          raise "fail on Bob" if record.data["name"] == "Bob"

          names << record.data["name"]
        end
      end
    end

    let(:all_import) do
      DataPorter::Registry.register(:all_or_nothing, all_or_nothing_target)
      DataPorter::DataImport.create!(
        target_key: "all_or_nothing",
        source_type: "csv",
        user_type: "User",
        user_id: 1
      )
    end

    before do
      orchestrator = described_class.new(all_import, content: "name\nAlice\nBob\n")
      orchestrator.parse!
    end

    it "transitions to failed when any record fails in :all mode" do
      original = DataPorter.configuration.transaction_mode
      DataPorter.configuration.transaction_mode = :all
      orchestrator = described_class.new(all_import)

      orchestrator.import!

      expect(all_import.reload.status).to eq("failed")
      expect(all_import.report.error_reports.first.message).to include("fail on Bob")
    ensure
      DataPorter.configuration.transaction_mode = original
    end

    it "persists successful records in :per_record mode despite errors" do
      original = DataPorter.configuration.transaction_mode
      DataPorter.configuration.transaction_mode = :per_record
      orchestrator = described_class.new(all_import)

      orchestrator.import!

      expect(all_import.reload.status).to eq("completed")
      expect(persisted_names).to eq(["Alice"])
    ensure
      DataPorter.configuration.transaction_mode = original
    end
  end

  describe "webhook notifications" do
    let(:webhook_target) do
      records = persisted_records
      Class.new(DataPorter::Target) do
        label "WebhookGuests"
        model_name "WebhookGuest"
        sources :csv

        columns do
          column :first_name, type: :string, required: true
        end

        webhooks do
          webhook "https://hooks.example.com/test",
                  events: %i[started completed failed parsed]
        end

        define_method(:persist) do |record, **|
          records << record.data
        end
      end
    end

    let(:webhook_import) do
      DataPorter::Registry.register(:webhook_guests, webhook_target)
      DataPorter::DataImport.create!(
        target_key: "webhook_guests",
        source_type: "csv",
        user_type: "User",
        user_id: 1
      )
    end

    before do
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    end

    it "notifies import.parsed after successful parse" do
      orchestrator = described_class.new(webhook_import, content: "first_name\nAlice\n")

      orchestrator.parse!

      jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j["job_class"] == "DataPorter::WebhookJob" }
      expect(jobs.size).to eq(1)
      payload = JSON.parse(jobs.first["arguments"][1])
      expect(payload["event"]).to eq("import.parsed")
    end

    it "notifies import.started when import begins" do
      orchestrator = described_class.new(webhook_import, content: "first_name\nAlice\n")
      orchestrator.parse!
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      orchestrator = described_class.new(webhook_import)
      orchestrator.import!

      all_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
      webhook_jobs = all_jobs.select { |j| j["job_class"] == "DataPorter::WebhookJob" }
      events = webhook_jobs.map { |j| JSON.parse(j["arguments"][1])["event"] }
      expect(events).to include("import.started")
    end

    it "notifies import.completed after successful import" do
      orchestrator = described_class.new(webhook_import, content: "first_name\nAlice\n")
      orchestrator.parse!
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      orchestrator = described_class.new(webhook_import)
      orchestrator.import!

      all_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
      webhook_jobs = all_jobs.select { |j| j["job_class"] == "DataPorter::WebhookJob" }
      events = webhook_jobs.map { |j| JSON.parse(j["arguments"][1])["event"] }
      expect(events).to include("import.completed")
    end

    it "notifies import.failed on catastrophic error" do
      webhook_import.update!(records: [])
      allow(webhook_import).to receive(:importable_records).and_raise("fatal")
      orchestrator = described_class.new(webhook_import)

      orchestrator.import!

      jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j["job_class"] == "DataPorter::WebhookJob" }
      events = jobs.map { |j| JSON.parse(j["arguments"][1]) }
      failed_payload = events.find { |p| p["event"] == "import.failed" }
      expect(failed_payload).not_to be_nil
      expect(failed_payload["import"]["error_message"]).to eq("fatal")
    end
  end
end
