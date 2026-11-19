# frozen_string_literal: true

RSpec.describe DataPorter::RecordUpdater, "update mode" do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Contacts"
      model_name "Contact"
      match_by :email

      def existing_scope = Contact.all

      columns do
        column :first_name, type: :string
        column :email, type: :email
      end
    end
  end

  let(:data_import) do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:contacts, target_class)
    DataPorter::DataImport.create!(target_key: "contacts", source_type: "csv", status: :previewing)
  end

  let(:csv_content) { "first_name,email\nAlicia,alice@example.com\nBob,bob@example.com\n" }
  let(:updater) { described_class.new(data_import.reload) }

  before do
    allow(ActionCable.server).to receive(:broadcast)
    Contact.delete_all
    Contact.create!(first_name: "Alicia", email: "alice@example.com")
    DataPorter::Orchestrator.new(data_import, content: csv_content).parse!
  end

  after { DataPorter::Registry.clear }

  def record(line)
    data_import.reload.records.find { |r| r.line_number == line }
  end

  it "recomputes the diff when a regular cell is edited" do
    updater.call(line_number: 1, column: "first_name", value: "Alice")

    expect(record(1).action).to eq("update")
    expect(record(1).diff).to eq("first_name" => %w[Alicia Alice])
  end

  it "keeps a record unchanged when a cell is cleared" do
    updater.call(line_number: 1, column: "first_name", value: "")

    expect(record(1).action).to eq("unchanged")
    expect(record(1).diff).to eq({})
  end

  it "resolves the record again when its match key is edited" do
    updater.call(line_number: 1, column: "email", value: "new@example.com")

    expect(record(1).action).to eq("create")
    expect(record(1).diff).to eq({})
  end

  it "flags a duplicate when the key is edited to an earlier line key" do
    updater.call(line_number: 2, column: "email", value: "alice@example.com")

    expect(record(2).errors_list.map(&:message)).to eq(["Duplicate email with line 1"])
    expect(record(2).status).to eq("partial")
  end

  it "moves action counts in the report" do
    updater.call(line_number: 1, column: "first_name", value: "Alice")

    report = data_import.reload.report
    expect([report.create_count, report.update_count, report.unchanged_count]).to eq([1, 1, 0])
  end

  it "returns the action and diff in the response" do
    result = updater.call(line_number: 1, column: "first_name", value: "Alice")

    expect(result[:action]).to eq("update")
    expect(result[:diff]).to eq("first_name" => %w[Alicia Alice])
    expect(result[:report]).to include(create_count: 1, update_count: 1, unchanged_count: 0)
  end
end
