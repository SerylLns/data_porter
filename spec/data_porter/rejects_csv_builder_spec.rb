# frozen_string_literal: true

RSpec.describe DataPorter::RejectsCsvBuilder do
  let(:columns) do
    [
      DataPorter::DSL::Column.new(name: :first_name, type: :string),
      DataPorter::DSL::Column.new(name: :email, type: :email)
    ]
  end

  let(:records) do
    [
      DataPorter::StoreModels::ImportRecord.new(
        line_number: 1,
        status: "complete",
        data: { "first_name" => "Alice", "email" => "alice@example.com" }
      ),
      DataPorter::StoreModels::ImportRecord.new(
        line_number: 2,
        status: "missing",
        data: { "first_name" => "", "email" => "bob@example.com" },
        errors_list: [DataPorter::StoreModels::Error.new(message: "first_name is required")]
      ),
      DataPorter::StoreModels::ImportRecord.new(
        line_number: 3,
        status: "partial",
        data: { "first_name" => "Charlie", "email" => "not-an-email" },
        errors_list: [DataPorter::StoreModels::Error.new(message: "email is not a valid email")]
      )
    ]
  end

  subject(:csv) { described_class.new(columns, records).generate }

  it "returns a CSV string" do
    expect(csv).to be_a(String)
  end

  it "includes a header row with column names and errors" do
    header = CSV.parse(csv).first

    expect(header).to eq(%w[line first_name email errors])
  end

  it "only includes rejected records" do
    rows = CSV.parse(csv)

    expect(rows.size).to eq(3)
  end

  it "includes error messages in the last column" do
    rows = CSV.parse(csv)

    expect(rows[1].last).to eq("first_name is required")
    expect(rows[2].last).to eq("email is not a valid email")
  end

  it "joins multiple errors with semicolons" do
    records[1].errors_list << DataPorter::StoreModels::Error.new(message: "another error")
    csv_output = described_class.new(columns, records).generate
    rows = CSV.parse(csv_output)

    expect(rows[1].last).to eq("first_name is required; another error")
  end

  it "returns only headers when no rejected records" do
    complete_records = [records.first]
    csv_output = described_class.new(columns, complete_records).generate
    rows = CSV.parse(csv_output)

    expect(rows.size).to eq(1)
  end
end
