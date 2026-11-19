# frozen_string_literal: true

RSpec.describe DataPorter::RecordDiffer do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      model_name "Contact"

      columns do
        column :email,      type: :email
        column :first_name, type: :string
        column :age,        type: :integer
        column :score,      type: :decimal
        column :active,     type: :boolean
        column :born_on,    type: :date
        column :nickname,   type: :string
      end
    end
  end

  let(:differ) { described_class.new(target_class.new) }
  let(:existing) do
    Contact.new(email: "alice@example.com", first_name: "Alice", age: 30, score: 12.5,
                active: true, born_on: Date.new(1990, 1, 2))
  end

  def build_record(data)
    DataPorter::StoreModels::ImportRecord.new(data: data)
  end

  it "returns an empty hash when nothing changed" do
    record = build_record("email" => "alice@example.com", "first_name" => "Alice")

    expect(differ.call(record, existing)).to eq({})
  end

  it "returns changed fields as [old, new]" do
    record = build_record("first_name" => "Alicia")

    expect(differ.call(record, existing)).to eq("first_name" => %w[Alice Alicia])
  end

  it "casts integers before comparing" do
    expect(differ.call(build_record("age" => "30"), existing)).to eq({})
  end

  it "casts decimals before comparing" do
    expect(differ.call(build_record("score" => "12.50"), existing)).to eq({})
  end

  it "casts booleans before comparing" do
    expect(differ.call(build_record("active" => "1"), existing)).to eq({})
  end

  it "casts dates before comparing" do
    expect(differ.call(build_record("born_on" => "1990-01-02"), existing)).to eq({})
  end

  it "ignores nil incoming values" do
    expect(differ.call(build_record("first_name" => nil), existing)).to eq({})
  end

  it "ignores empty and whitespace-only incoming values" do
    expect(differ.call(build_record("first_name" => "", "nickname" => "  "), existing)).to eq({})
  end

  it "reports false booleans as a change" do
    expect(differ.call(build_record("active" => false), existing)).to eq("active" => [true, false])
  end

  it "treats an empty string and nil as equal" do
    expect(differ.call(build_record("email" => ""), Contact.new)).to eq({})
  end

  it "ignores columns that are not model attributes" do
    expect(differ.call(build_record("nickname" => "Ali"), existing)).to eq({})
  end

  it "serializes old values as JSON-friendly strings" do
    record = build_record("score" => "13", "born_on" => "1991-05-06")

    expect(differ.call(record, existing)).to eq(
      "score" => %w[12.5 13], "born_on" => %w[1990-01-02 1991-05-06]
    )
  end

  it "uses the target diff_attributes hook" do
    target_class.define_method(:diff_attributes) { |model| { "nickname" => model.first_name } }

    expect(differ.call(build_record("nickname" => "Ali"), existing)).to eq("nickname" => %w[Alice Ali])
  end
end
