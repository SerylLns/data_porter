# frozen_string_literal: true

RSpec.describe DataPorter::RecordUpdater do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"

      columns do
        column :name, type: :string, required: true
        column :email, type: :string, required: true, transform: %i[strip downcase]
      end
    end
  end

  before do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:guests, target_class)
  end

  after { DataPorter::Registry.clear }

  let(:complete_record) do
    DataPorter::StoreModels::ImportRecord.new(
      line_number: 1,
      status: "complete",
      data: { "name" => "Alice", "email" => "alice@test.com" }
    )
  end

  let(:missing_record) do
    r = DataPorter::StoreModels::ImportRecord.new(
      line_number: 2,
      status: "missing",
      data: { "name" => "", "email" => "bob@test.com" }
    )
    r.add_error("Name is required")
    r
  end

  let(:report) do
    DataPorter::StoreModels::Report.new(
      records_count: 2,
      complete_count: 1,
      partial_count: 0,
      missing_count: 1
    )
  end

  let(:data_import) do
    DataPorter::DataImport.create!(
      target_key: "guests",
      source_type: "csv",
      status: :previewing,
      records: [complete_record, missing_record],
      report: report
    )
  end

  let(:updater) { described_class.new(data_import) }

  describe "#call" do
    context "when fixing a missing field" do
      it "updates the record data" do
        result = updater.call(line_number: 2, column: "name", value: "Bob")
        expect(result[:value]).to eq("Bob")
      end

      it "changes record status from missing to complete" do
        result = updater.call(line_number: 2, column: "name", value: "Bob")
        expect(result[:status]).to eq("complete")
      end

      it "clears errors on the record" do
        result = updater.call(line_number: 2, column: "name", value: "Bob")
        expect(result[:errors]).to be_empty
      end

      it "updates report counts" do
        result = updater.call(line_number: 2, column: "name", value: "Bob")
        expect(result[:report][:complete_count]).to eq(2)
        expect(result[:report][:missing_count]).to eq(0)
      end

      it "persists changes to the database" do
        updater.call(line_number: 2, column: "name", value: "Bob")
        data_import.reload
        record = data_import.records.find { |r| r.line_number == 2 }
        expect(record.status).to eq("complete")
      end
    end

    context "when breaking a valid field" do
      it "changes status from complete to missing" do
        result = updater.call(line_number: 1, column: "name", value: "")
        expect(result[:status]).to eq("missing")
      end

      it "adds validation errors" do
        result = updater.call(line_number: 1, column: "name", value: "")
        expect(result[:errors]).to include("Name is required")
      end

      it "updates report counts" do
        result = updater.call(line_number: 1, column: "name", value: "")
        expect(result[:report][:complete_count]).to eq(0)
        expect(result[:report][:missing_count]).to eq(2)
      end
    end

    context "when applying transforms" do
      it "returns the transformed value" do
        result = updater.call(line_number: 1, column: "email", value: " ALICE@NEW.COM ")
        expect(result[:value]).to eq("alice@new.com")
      end
    end

    context "when record is not found" do
      it "raises an error" do
        expect { updater.call(line_number: 999, column: "name", value: "X") }
          .to raise_error(DataPorter::Error, /not found/)
      end
    end

    context "when status does not change" do
      it "does not alter report counts" do
        result = updater.call(line_number: 1, column: "name", value: "Updated")
        expect(result[:report][:complete_count]).to eq(1)
        expect(result[:report][:missing_count]).to eq(1)
      end
    end
  end
end
