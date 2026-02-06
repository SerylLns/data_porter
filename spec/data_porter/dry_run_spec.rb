# frozen_string_literal: true

RSpec.describe "Dry Run" do
  let(:target_class) do
    klass = Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"
      dry_run_enabled

      columns do
        column :first_name, type: :string, required: true
        column :last_name, type: :string
      end
    end
    klass.define_method(:persist) do |record, context:| # rubocop:disable Lint/UnusedBlockArgument
      # Simulate successful persist
      record
    end
    klass
  end

  let(:failing_target_class) do
    klass = Class.new(DataPorter::Target) do
      label "Failing"
      model_name "Failing"
      dry_run_enabled

      columns do
        column :name, type: :string, required: true
      end
    end
    klass.define_method(:persist) do |_record, context:| # rubocop:disable Lint/UnusedBlockArgument
      raise ActiveRecord::RecordInvalid.new, "Validation failed: Email already taken"
    end
    klass
  end

  before do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:guests, target_class)
  end

  after { DataPorter::Registry.clear }

  describe "Target DSL" do
    it "enables dry_run via dry_run_enabled" do
      expect(target_class._dry_run_enabled).to be true
    end

    it "defaults to false when not set" do
      plain = Class.new(DataPorter::Target) do
        label "Plain"
        model_name "Plain"
      end
      expect(plain._dry_run_enabled).to be_falsey
    end
  end

  describe "DataImport dry_running status" do
    it "supports dry_running status" do
      import = DataPorter::DataImport.create!(
        target_key: "guests", source_type: "csv",
        user_type: "User", user_id: 1
      )
      import.dry_running!
      expect(import.reload.status).to eq("dry_running")
    end
  end

  describe "Orchestrator#dry_run!" do
    let(:csv_content) { "First Name,Last Name\nAlice,Smith\nBob,Jones\n" }

    let(:import) do
      DataPorter::DataImport.create!(
        target_key: "guests", source_type: "csv",
        user_type: "User", user_id: 1
      )
    end

    before do
      DataPorter::Orchestrator.new(import, content: csv_content).parse!
    end

    it "transitions to previewing after dry run" do
      DataPorter::Orchestrator.new(import.reload).dry_run!
      expect(import.reload.status).to eq("previewing")
    end

    it "marks records as dry_run_passed on success" do
      DataPorter::Orchestrator.new(import.reload).dry_run!
      import.reload.records.each do |record|
        expect(record.dry_run_passed).to be true
      end
    end

    it "captures errors from failing persist" do
      DataPorter::Registry.register(:failing, failing_target_class)
      failing_import = DataPorter::DataImport.create!(
        target_key: "failing", source_type: "csv",
        user_type: "User", user_id: 1
      )
      DataPorter::Orchestrator.new(failing_import, content: "Name\nAlice\n").parse!

      DataPorter::Orchestrator.new(failing_import.reload).dry_run!

      record = failing_import.reload.records.first
      expect(record.dry_run_passed).to be false
      expect(record.errors_list.map(&:message)).to include(match(/Validation failed/))
    end

    it "returns to previewing even after errors" do
      DataPorter::Registry.register(:failing, failing_target_class)
      failing_import = DataPorter::DataImport.create!(
        target_key: "failing", source_type: "csv",
        user_type: "User", user_id: 1
      )
      DataPorter::Orchestrator.new(failing_import, content: "Name\nAlice\n").parse!

      DataPorter::Orchestrator.new(failing_import.reload).dry_run!

      expect(failing_import.reload.status).to eq("previewing")
    end
  end

  describe "DryRunJob" do
    it "calls Orchestrator#dry_run!" do
      import = DataPorter::DataImport.create!(
        target_key: "guests", source_type: "csv",
        user_type: "User", user_id: 1
      )
      orchestrator = instance_double(DataPorter::Orchestrator, dry_run!: nil)
      allow(DataPorter::Orchestrator).to receive(:new).and_return(orchestrator)

      DataPorter::DryRunJob.new.perform(import.id)

      expect(orchestrator).to have_received(:dry_run!)
    end

    it "uses the configured queue name" do
      job = DataPorter::DryRunJob.new
      expect(job.queue_name).to eq("imports")
    end
  end
end
