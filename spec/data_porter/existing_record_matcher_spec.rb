# frozen_string_literal: true

RSpec.describe DataPorter::ExistingRecordMatcher do
  def build_record(data)
    DataPorter::StoreModels::ImportRecord.new(data: data)
  end

  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end

  before { Contact.delete_all }

  describe "#call" do
    it "returns existing records indexed by key tuple" do
      alice = Contact.create!(email: "alice@example.com")
      matcher = described_class.new(Contact.all, [:email])

      result = matcher.call([build_record("email" => "alice@example.com")])

      expect(result).to eq(["alice@example.com"] => [alice])
    end

    it "omits records that do not exist" do
      matcher = described_class.new(Contact.all, [:email])

      result = matcher.call([build_record("email" => "nobody@example.com")])

      expect(result).to eq({})
    end

    it "matches composite keys on the exact tuple only" do
      alice = Contact.create!(first_name: "Alice", last_name: "Smith")
      Contact.create!(first_name: "Bob", last_name: "Jones")
      matcher = described_class.new(Contact.all, %i[first_name last_name])
      records = [
        build_record("first_name" => "Alice", "last_name" => "Smith"),
        build_record("first_name" => "Alice", "last_name" => "Jones")
      ]

      result = matcher.call(records)

      expect(result).to eq(%w[Alice Smith] => [alice])
    end

    it "only looks up records within the given scope" do
      Contact.create!(email: "alice@example.com", active: false)
      matcher = described_class.new(Contact.where(active: true), [:email])

      result = matcher.call([build_record("email" => "alice@example.com")])

      expect(result).to eq({})
    end

    it "groups several existing records sharing the same key" do
      first = Contact.create!(email: "dup@example.com")
      second = Contact.create!(email: "dup@example.com")
      matcher = described_class.new(Contact.all, [:email])

      result = matcher.call([build_record("email" => "dup@example.com")])

      expect(result[["dup@example.com"]]).to contain_exactly(first, second)
    end

    it "matches integer columns against string record values" do
      contact = Contact.create!(external_id: 42)
      matcher = described_class.new(Contact.all, [:external_id])

      result = matcher.call([build_record("external_id" => "42")])

      expect(result).to eq(["42"] => [contact])
    end

    it "does not query when every key is blank" do
      matcher = described_class.new(Contact.all, [:email])

      queries = count_queries { matcher.call([build_record("email" => nil), build_record("email" => "")]) }

      expect(queries).to eq(0)
    end

    it "queries once per batch of keys" do
      stub_const("#{described_class}::BATCH_SIZE", 2)
      matcher = described_class.new(Contact.all, [:email])
      records = Array.new(5) { |i| build_record("email" => "user#{i}@example.com") }

      queries = count_queries { matcher.call(records) }

      expect(queries).to eq(3)
    end

    context "with typed columns" do
      let(:caster) do
        DataPorter::ValueCaster.new(
          [
            DataPorter::DSL::Column.new(name: :external_id, type: :integer),
            DataPorter::DSL::Column.new(name: :score, type: :decimal)
          ]
        )
      end

      it "matches integer keys regardless of their textual format" do
        contact = Contact.create!(external_id: 7)
        matcher = described_class.new(Contact.all, [:external_id], caster: caster)

        result = matcher.call([build_record("external_id" => "007")])

        expect(result).to eq([7] => [contact])
      end

      it "matches decimal keys regardless of trailing zeros" do
        contact = Contact.create!(score: 1.5)
        matcher = described_class.new(Contact.all, [:score], caster: caster)

        result = matcher.call([build_record("score" => "1.50")])

        expect(result.values).to eq([[contact]])
      end
    end
  end

  describe "#key_for" do
    it "returns the stringified key values of a record" do
      matcher = described_class.new(Contact.all, %i[first_name external_id])

      expect(matcher.key_for(build_record("first_name" => "Alice", "external_id" => 7))).to eq(%w[Alice 7])
    end
  end

  describe "#blank_key?" do
    let(:matcher) { described_class.new(Contact.all, %i[first_name last_name]) }

    it "is true when any key value is nil or blank" do
      expect([matcher.blank_key?(["Alice", nil]), matcher.blank_key?(["Alice", "  "])]).to eq([true, true])
    end

    it "is false when every key value is present" do
      expect(matcher.blank_key?(["Alice", 0])).to be(false)
    end
  end

  describe ".for" do
    let(:target_class) do
      Class.new(DataPorter::Target) do
        match_by :external_id

        def existing_scope = Contact.all

        columns do
          column :external_id, type: :integer
        end
      end
    end

    it "casts keys with the target column types" do
      contact = Contact.create!(external_id: 7)

      result = described_class.for(target_class.new).call([build_record("external_id" => "007")])

      expect(result).to eq([7] => [contact])
    end
  end
end
