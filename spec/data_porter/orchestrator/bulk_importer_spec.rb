# frozen_string_literal: true

RSpec.describe DataPorter::Orchestrator do
  describe "bulk import" do
    let(:persisted_batches) { [] }
    let(:persisted_records) { [] }

    let(:bulk_target) do
      batches = persisted_batches
      Class.new(DataPorter::Target) do
        label "BulkGuests"
        model_name "Guest"
        sources :csv
        bulk_mode batch_size: 2

        columns do
          column :name, type: :string, required: true
        end

        define_method(:persist_batch) do |records, **|
          batches << records.map(&:data)
        end

        define_method(:persist) do |record, **|
          # noop
        end
      end
    end

    let(:data_import) do
      DataPorter::Registry.clear
      DataPorter::Registry.register(:bulk_guests, bulk_target)
      DataPorter::DataImport.create!(
        target_key: "bulk_guests",
        source_type: "csv",
        user_type: "User",
        user_id: 1
      )
    end

    let(:csv_content) { "name\nAlice\nBob\nCharlie\nDiana\nEve\n" }

    before do
      allow(ActionCable.server).to receive(:broadcast)
      orchestrator = described_class.new(data_import, content: csv_content)
      orchestrator.parse!
    end

    it "uses batch persistence when bulk_mode is configured" do
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(persisted_batches.size).to eq(3)
    end

    it "respects batch_size" do
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(persisted_batches[0].size).to eq(2)
      expect(persisted_batches[1].size).to eq(2)
      expect(persisted_batches[2].size).to eq(1)
    end

    it "transitions to completed" do
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(data_import.reload.status).to eq("completed")
    end

    it "updates report with correct counts" do
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      report = data_import.reload.report
      expect(report.imported_count).to eq(5)
      expect(report.errored_count).to eq(0)
    end

    it "saves checkpoint to config after each batch" do
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      checkpoint = data_import.reload.config["checkpoint"]
      expect(checkpoint["processed"]).to eq(5)
      expect(checkpoint["created"]).to eq(5)
      expect(checkpoint["errored"]).to eq(0)
    end

    it "broadcasts progress per batch, not per record" do
      broadcaster = instance_double(DataPorter::Broadcaster)
      allow(DataPorter::Broadcaster).to receive(:new).and_return(broadcaster)
      allow(broadcaster).to receive(:progress)
      allow(broadcaster).to receive(:success)
      orchestrator = described_class.new(data_import)

      orchestrator.import!

      expect(broadcaster).to have_received(:progress).exactly(3).times
      expect(broadcaster).to have_received(:progress).with(2, 5)
      expect(broadcaster).to have_received(:progress).with(4, 5)
      expect(broadcaster).to have_received(:progress).with(5, 5)
    end

    context "with retry_per_record on batch failure" do
      let(:fail_once_target) do
        attempt = [0]
        records = persisted_records
        Class.new(DataPorter::Target) do
          label "FailOnce"
          model_name "FailOnce"
          sources :csv
          bulk_mode batch_size: 2, on_conflict: :retry_per_record

          columns do
            column :name, type: :string, required: true
          end

          define_method(:persist_batch) do |_batch, **|
            attempt[0] += 1
            raise "batch error" if attempt[0] == 1
          end

          define_method(:persist) do |record, **|
            records << record.data
          end
        end
      end

      let(:data_import) do
        DataPorter::Registry.clear
        DataPorter::Registry.register(:fail_once, fail_once_target)
        DataPorter::DataImport.create!(
          target_key: "fail_once",
          source_type: "csv",
          user_type: "User",
          user_id: 1
        )
      end

      let(:csv_content) { "name\nAlice\nBob\n" }

      it "retries failed batch records individually" do
        orchestrator = described_class.new(data_import)

        orchestrator.import!

        expect(persisted_records.size).to eq(2)
      end

      it "counts retried records as created" do
        orchestrator = described_class.new(data_import)

        orchestrator.import!

        report = data_import.reload.report
        expect(report.imported_count).to eq(2)
      end
    end

    context "with retry_per_record when individual record also fails" do
      let(:partial_fail_target) do
        records = persisted_records
        Class.new(DataPorter::Target) do
          label "PartialFail"
          model_name "PartialFail"
          sources :csv
          bulk_mode batch_size: 2, on_conflict: :retry_per_record

          columns do
            column :name, type: :string, required: true
          end

          define_method(:persist_batch) do |_batch, **|
            raise "batch error"
          end

          define_method(:persist) do |record, **|
            raise "record error" if record.data["name"] == "Bob"

            records << record.data
          end
        end
      end

      let(:data_import) do
        DataPorter::Registry.clear
        DataPorter::Registry.register(:partial_fail, partial_fail_target)
        DataPorter::DataImport.create!(
          target_key: "partial_fail",
          source_type: "csv",
          user_type: "User",
          user_id: 1
        )
      end

      let(:csv_content) { "name\nAlice\nBob\n" }

      it "counts individual failures as errored" do
        orchestrator = described_class.new(data_import)

        orchestrator.import!

        report = data_import.reload.report
        expect(report.imported_count).to eq(1)
        expect(report.errored_count).to eq(1)
      end
    end

    context "with fail_batch on_conflict" do
      let(:fail_batch_target) do
        Class.new(DataPorter::Target) do
          label "FailBatch"
          model_name "FailBatch"
          sources :csv
          bulk_mode batch_size: 2, on_conflict: :fail_batch

          columns do
            column :name, type: :string, required: true
          end

          define_method(:persist_batch) do |_batch, **|
            raise "batch error"
          end

          define_method(:persist) do |_record, **|
            # noop
          end
        end
      end

      let(:data_import) do
        DataPorter::Registry.clear
        DataPorter::Registry.register(:fail_batch, fail_batch_target)
        DataPorter::DataImport.create!(
          target_key: "fail_batch",
          source_type: "csv",
          user_type: "User",
          user_id: 1
        )
      end

      let(:csv_content) { "name\nAlice\nBob\nCharlie\n" }

      it "marks all batch records as errored" do
        orchestrator = described_class.new(data_import)

        orchestrator.import!

        report = data_import.reload.report
        expect(report.errored_count).to eq(3)
        expect(report.imported_count).to eq(0)
      end

      it "does not retry individually" do
        orchestrator = described_class.new(data_import)
        orchestrator.import!

        target_instance = orchestrator.instance_variable_get(:@target)
        allow(target_instance).to receive(:persist).and_call_original

        expect(target_instance).not_to have_received(:persist)
      end

      it "still completes the import" do
        orchestrator = described_class.new(data_import)

        orchestrator.import!

        expect(data_import.reload.status).to eq("completed")
      end
    end
  end
end
