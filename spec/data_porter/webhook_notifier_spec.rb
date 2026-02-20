# frozen_string_literal: true

RSpec.describe DataPorter::WebhookNotifier do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "HookTarget"
      model_name "HookTarget"
      sources :csv

      columns do
        column :name, type: :string
      end

      webhooks do
        webhook "https://hooks.slack.com/xxx",
                events: %i[completed failed],
                headers: { "X-Team" => "ops" }
        webhook "https://monitoring.internal/ingest",
                events: [:completed]
      end
    end
  end

  let(:data_import) do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:hook_target, target_class)
    DataPorter::DataImport.create!(
      target_key: "hook_target",
      source_type: "csv",
      user_type: "User",
      user_id: 1,
      records: [],
      report: DataPorter::StoreModels::Report.new(
        records_count: 100,
        complete_count: 80,
        partial_count: 20,
        imported_count: 95,
        errored_count: 5
      )
    )
  end

  def enqueued_jobs
    ActiveJob::Base.queue_adapter.enqueued_jobs
  end

  before do
    enqueued_jobs.clear
  end

  describe ".notify" do
    it "enqueues a job for each matching webhook" do
      described_class.notify(data_import, "import.completed")

      expect(enqueued_jobs.size).to eq(2)
      expect(enqueued_jobs.map { |j| j["job_class"] }).to all(eq("DataPorter::WebhookJob"))
    end

    it "filters webhooks by event" do
      described_class.notify(data_import, "import.started")

      expect(enqueued_jobs).to be_empty
    end

    it "is a no-op when target has no webhooks" do
      no_hook_target = Class.new(DataPorter::Target) do
        label "NoHook"
        model_name "NoHook"
        sources :csv
        columns do
          column :name, type: :string
        end
      end
      DataPorter::Registry.register(:no_hook, no_hook_target)
      import = DataPorter::DataImport.create!(
        target_key: "no_hook",
        source_type: "csv",
        user_type: "User",
        user_id: 1
      )

      described_class.notify(import, "import.completed")

      expect(enqueued_jobs).to be_empty
    end

    it "passes the url, payload json, and headers to the job" do
      described_class.notify(data_import, "import.completed")

      args = enqueued_jobs.first["arguments"]
      expect(args[0]).to eq("https://hooks.slack.com/xxx")
      payload = JSON.parse(args[1])
      expect(payload["event"]).to eq("import.completed")
      expect(payload["import"]["target_key"]).to eq("hook_target")
    end
  end

  describe "payload building" do
    it "includes event and timestamp" do
      described_class.notify(data_import, "import.completed")

      payload = JSON.parse(enqueued_jobs.first["arguments"][1])
      expect(payload["event"]).to eq("import.completed")
      expect(payload).to have_key("timestamp")
    end

    it "includes import metadata" do
      described_class.notify(data_import, "import.completed")

      payload = JSON.parse(enqueued_jobs.first["arguments"][1])
      import_data = payload["import"]
      expect(import_data["id"]).to eq(data_import.id)
      expect(import_data["source_type"]).to eq("csv")
    end

    it "includes imported/errored counts for completed event" do
      described_class.notify(data_import, "import.completed")

      payload = JSON.parse(enqueued_jobs.first["arguments"][1])
      import_data = payload["import"]
      expect(import_data["imported_count"]).to eq(95)
      expect(import_data["errored_count"]).to eq(5)
    end

    it "includes error_message for failed event" do
      data_import.update!(
        status: :failed,
        report: DataPorter::StoreModels::Report.new(
          error_reports: [DataPorter::StoreModels::Error.new(message: "DB down")]
        )
      )

      described_class.notify(data_import, "import.failed")

      payload = JSON.parse(enqueued_jobs.first["arguments"][1])
      expect(payload["import"]["error_message"]).to eq("DB down")
    end

    it "includes record counts for parsed event" do
      data_import.update!(
        report: DataPorter::StoreModels::Report.new(
          records_count: 100,
          complete_count: 80,
          partial_count: 20
        )
      )
      target_class._webhooks.first.events << :parsed

      described_class.notify(data_import, "import.parsed")

      payload = JSON.parse(enqueued_jobs.first["arguments"][1])
      import_data = payload["import"]
      expect(import_data["records_count"]).to eq(100)
      expect(import_data["complete_count"]).to eq(80)
      expect(import_data["partial_count"]).to eq(20)
    end
  end

  describe "custom payload lambda" do
    it "applies the custom payload transformer" do
      custom_target = Class.new(DataPorter::Target) do
        label "CustomPayload"
        model_name "CustomPayload"
        sources :csv
        columns do
          column :name, type: :string
        end

        webhooks do
          webhook "https://custom.com/hook",
                  events: [:completed],
                  payload: ->(_import, _event, data) { data.merge("team" => "ops") }
        end
      end
      DataPorter::Registry.register(:custom_payload, custom_target)
      import = DataPorter::DataImport.create!(
        target_key: "custom_payload",
        source_type: "csv",
        user_type: "User",
        user_id: 1,
        report: DataPorter::StoreModels::Report.new(imported_count: 10, errored_count: 0)
      )

      described_class.notify(import, "import.completed")

      payload = JSON.parse(enqueued_jobs.first["arguments"][1])
      expect(payload["team"]).to eq("ops")
      expect(payload["event"]).to eq("import.completed")
    end
  end

  describe "custom headers" do
    it "passes webhook-specific headers to the job" do
      described_class.notify(data_import, "import.completed")

      headers = enqueued_jobs.first["arguments"][2]
      expect(headers).to include("X-Team" => "ops")
    end

    it "passes empty headers for webhooks without custom headers" do
      described_class.notify(data_import, "import.completed")

      headers = enqueued_jobs.second["arguments"][2]
      expect(headers).not_to have_key("X-Team")
    end
  end
end
