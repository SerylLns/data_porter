# frozen_string_literal: true

RSpec.describe DataPorter::RecordExcluder do
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

  let(:csv_content) { "first_name,email\nAlice,alice@example.com\nBob,bob@example.com\n" }
  let(:excluder) { described_class.new(data_import.reload) }

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

  def counts
    report = data_import.reload.report
    [report.create_count, report.update_count, report.excluded_count]
  end

  it "marks the record as excluded and persists it" do
    excluder.call(line_number: 1, excluded: true)

    expect(record(1).excluded).to be(true)
  end

  it "moves the record out of its action count" do
    excluder.call(line_number: 1, excluded: true)

    expect(counts).to eq([1, 0, 1])
  end

  it "moves the record back when included again" do
    excluder.call(line_number: 1, excluded: true)
    described_class.new(data_import.reload).call(line_number: 1, excluded: false)

    expect([record(1).excluded, *counts]).to eq([false, 1, 1, 0])
  end

  it "does not count a record twice when excluded twice" do
    excluder.call(line_number: 1, excluded: true)
    described_class.new(data_import.reload).call(line_number: 1, excluded: true)

    expect(counts).to eq([1, 0, 1])
  end

  it "returns the excluded flag and the preview counts" do
    result = excluder.call(line_number: 2, excluded: true)

    expect(result[:excluded]).to be(true)
    expect(result[:report]).to include(create_count: 0, update_count: 1, excluded_count: 1)
  end

  it "raises Error for an unknown line" do
    expect { excluder.call(line_number: 99, excluded: true) }.to raise_error(DataPorter::Error, /99/)
  end
end
