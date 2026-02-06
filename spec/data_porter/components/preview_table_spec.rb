# frozen_string_literal: true

RSpec.describe DataPorter::Components::PreviewTable do
  def render(component)
    component.call
  end

  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"

      columns do
        column :first_name, type: :string, required: true
        column :last_name, type: :string
      end
    end
  end

  let(:record) do
    DataPorter::StoreModels::ImportRecord.new(
      line_number: 1,
      status: "complete",
      data: { "first_name" => "Alice", "last_name" => "Smith" }
    )
  end

  let(:error_record) do
    r = DataPorter::StoreModels::ImportRecord.new(
      line_number: 2,
      status: "missing",
      data: { "first_name" => "", "last_name" => "Jones" }
    )
    r.add_error("First name is required")
    r
  end

  it "renders column headers from target" do
    html = render(described_class.new(columns: target_class._columns, records: [record]))

    expect(html).to include("First name")
    expect(html).to include("Last name")
  end

  it "renders record data in rows" do
    html = render(described_class.new(columns: target_class._columns, records: [record]))

    expect(html).to include("Alice")
    expect(html).to include("Smith")
  end

  it "renders error messages" do
    html = render(described_class.new(columns: target_class._columns, records: [error_record]))

    expect(html).to include("First name is required")
  end

  it "includes status-specific row class" do
    html = render(described_class.new(columns: target_class._columns, records: [record]))
    expect(html).to include("dp-row--complete")
  end

  it "wraps in dp-preview-table container" do
    html = render(described_class.new(columns: target_class._columns, records: [record]))
    expect(html).to include("dp-preview-table")
  end
end
