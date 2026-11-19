# frozen_string_literal: true

RSpec.describe DataPorter::Orchestrator, "update mode" do
  let(:after_import_results) { [] }
  let(:target_class) do
    received = after_import_results
    Class.new(DataPorter::Target) do
      label "Contacts"
      model_name "Contact"
      sources :csv
      match_by :email

      def existing_scope = Contact.all

      columns do
        column :first_name, type: :string
        column :email, type: :email
      end

      csv_mapping do
        map "First Name" => :first_name
        map "Email" => :email
      end

      define_method(:persist) { |record, **| Contact.create!(record.attributes) }
      define_method(:after_import) { |results, **| received << results }
    end
  end

  let(:csv_content) do
    "First Name,Email\nAlice,alice@example.com\nBob,bob@example.com\nCarol,carol@example.com\n"
  end

  let(:data_import) do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:contacts, target_class)
    DataPorter::DataImport.create!(target_key: "contacts", source_type: "csv")
  end

  before do
    allow(ActionCable.server).to receive(:broadcast)
    Contact.delete_all
    Contact.create!(first_name: "Alicia", email: "alice@example.com")
    Contact.create!(first_name: "Bob", email: "bob@example.com")
    described_class.new(data_import, content: csv_content).parse!
  end

  def import!
    described_class.new(data_import.reload).import!
    data_import.reload
  end

  describe "#import!" do
    it "creates unmatched records through persist" do
      import!

      expect(Contact.find_by(email: "carol@example.com").first_name).to eq("Carol")
    end

    it "updates changed records through the update hook" do
      import!

      expect(Contact.find_by(email: "alice@example.com").first_name).to eq("Alice")
    end

    it "does not write unchanged records" do
      bob = Contact.find_by(email: "bob@example.com")
      expect { import! }.not_to(change { bob.reload.updated_at })
      expect(Contact.where(email: "bob@example.com").count).to eq(1)
    end

    it "reports created, updated and skipped counts" do
      report = import!.report

      expect([report.imported_count, report.updated_count, report.skipped_count, report.errored_count])
        .to eq([1, 1, 1, 0])
    end

    it "passes every outcome to after_import" do
      import!

      expect(after_import_results.first).to eq(created: 1, updated: 1, skipped: 1, errored: 0)
    end

    it "looks up existing records again at import time" do
      Contact.create!(first_name: "Caroline", email: "carol@example.com")

      import!

      expect(Contact.where(email: "carol@example.com").pluck(:first_name)).to eq(["Carol"])
    end

    it "skips creations when apply_creates is disabled" do
      data_import.update!(config: data_import.config.merge("apply_creates" => false))

      report = import!.report

      expect(Contact.exists?(email: "carol@example.com")).to be false
      expect(report.skipped_count).to eq(2)
    end

    it "skips updates when apply_updates is disabled" do
      data_import.update!(config: data_import.config.merge("apply_updates" => false))

      import!

      expect(Contact.find_by(email: "alice@example.com").first_name).to eq("Alicia")
    end

    it "counts update failures as errored" do
      target_class.define_method(:update) { |*, **| raise "boom" }

      report = import!.report

      expect(report.errored_count).to eq(1)
      expect(report.updated_count).to eq(0)
    end

    it "seeds every outcome from the checkpoint when resuming" do
      checkpoint = { "processed" => 1, "created" => 0, "updated" => 1, "skipped" => 0, "errored" => 0 }
      data_import.update!(config: data_import.config.merge("checkpoint" => checkpoint))

      report = import!.report

      expect([report.imported_count, report.updated_count, report.skipped_count]).to eq([1, 1, 1])
    end

    it "dispatches actions in all-or-nothing transaction mode" do
      allow(DataPorter.configuration).to receive(:transaction_mode).and_return(:all)

      report = import!.report

      expect([report.imported_count, report.updated_count, report.skipped_count]).to eq([1, 1, 1])
      expect(Contact.find_by(email: "alice@example.com").first_name).to eq("Alice")
    end

    it "refuses a second write on the same key within a run" do
      records = data_import.records
      records.first.data["email"] = "carol@example.com"
      data_import.update!(records: records)

      report = import!.report

      expect(Contact.where(email: "carol@example.com").count).to eq(1)
      expect(report.errored_count).to eq(1)
    end

    it "fails with an explicit error when combined with bulk_mode" do
      target_class.bulk_mode

      import = import!

      expect(import.status).to eq("failed")
      expect(import.report.error_reports.first.message).to match(/bulk_mode.*match_by/)
    end
  end

  describe "#parse!" do
    it "clears apply options from a previous confirmation" do
      data_import.update!(config: data_import.config.merge("apply_updates" => false))

      described_class.new(data_import.reload, content: csv_content).parse!

      expect(data_import.reload.config).not_to have_key("apply_updates")
    end
  end

  describe "#dry_run!" do
    it "runs updates without persisting them" do
      described_class.new(data_import.reload).dry_run!

      expect(Contact.find_by(email: "alice@example.com").first_name).to eq("Alicia")
      expect(data_import.reload.records.first.dry_run_passed).to be true
    end

    it "keeps excluded records out of the action counts" do
      DataPorter::RecordExcluder.new(data_import.reload).call(line_number: 1, excluded: true)

      described_class.new(data_import.reload).dry_run!

      report = data_import.reload.report
      expect([report.update_count, report.excluded_count]).to eq([0, 1])
    end
  end

  describe "#import! with excluded records" do
    it "does not write excluded records" do
      DataPorter::RecordExcluder.new(data_import.reload).call(line_number: 3, excluded: true)

      import!

      expect(Contact.find_by(email: "carol@example.com")).to be_nil
    end
  end
end
