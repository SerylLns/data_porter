# frozen_string_literal: true

RSpec.describe DataPorter::RecordActionResolver do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      model_name "Contact"
      match_by :email

      def existing_scope = Contact.all

      columns do
        column :email,      type: :email
        column :first_name, type: :string
      end
    end
  end

  let(:resolver) { described_class.new(target_class.new) }

  def build_record(line, data)
    DataPorter::StoreModels::ImportRecord.new(line_number: line, data: data, status: "complete")
  end

  before { Contact.delete_all }

  it "marks unmatched records as create" do
    record = build_record(1, "email" => "new@example.com", "first_name" => "New")

    resolver.call([record])

    expect(record.action).to eq("create")
    expect(record.diff).to eq({})
  end

  it "marks matched records with changes as update with their diff" do
    Contact.create!(email: "alice@example.com", first_name: "Alice")
    record = build_record(1, "email" => "alice@example.com", "first_name" => "Alicia")

    resolver.call([record])

    expect(record.action).to eq("update")
    expect(record.diff).to eq("first_name" => %w[Alice Alicia])
  end

  it "marks matched records without changes as unchanged" do
    Contact.create!(email: "alice@example.com", first_name: "Alice")
    record = build_record(1, "email" => "alice@example.com", "first_name" => "Alice")

    resolver.call([record])

    expect(record.action).to eq("unchanged")
  end

  it "marks records with a blank match key as create" do
    record = build_record(1, "email" => nil, "first_name" => "Anonymous")

    resolver.call([record])

    expect(record.action).to eq("create")
  end

  it "flags later records sharing a match key with an earlier line" do
    first = build_record(1, "email" => "dup@example.com")
    second = build_record(2, "email" => "dup@example.com")

    resolver.call([first, second])

    expect(first.errors_list).to be_empty
    expect(second.errors_list.map(&:message)).to eq(["Duplicate email with line 1"])
    expect(second.status).to eq("partial")
  end

  it "flags records matching several existing records" do
    2.times { Contact.create!(email: "twin@example.com") }
    record = build_record(1, "email" => "twin@example.com")

    resolver.call([record])

    expect(record.errors_list.map(&:message)).to eq(["email matches 2 existing records"])
    expect(record.status).to eq("partial")
  end

  it "looks up existing records through the target existing_scope" do
    Contact.create!(email: "alice@example.com", active: false)
    target_class.define_method(:existing_scope) { Contact.where(active: true) }
    record = build_record(1, "email" => "alice@example.com")

    resolver.call([record])

    expect(record.action).to eq("create")
  end

  it "matches typed keys regardless of their textual format" do
    Contact.create!(email: "alice@example.com", external_id: 7)
    target_class.match_by :external_id
    target_class.columns { column :external_id, type: :integer }
    record = build_record(1, "external_id" => "007", "email" => "alice@example.com")

    resolver.call([record])

    expect(record.action).to eq("unchanged")
  end

  it "raises Error when a match key is not a declared column" do
    target_class.match_by :emial

    expect { resolver }.to raise_error(DataPorter::Error, /match_by.*emial/)
  end

  it "resets a previous diff when resolving again" do
    record = build_record(1, "email" => "new@example.com")
    record.diff = { "first_name" => %w[Old New] }

    resolver.call([record])

    expect(record.diff).to eq({})
  end
end
