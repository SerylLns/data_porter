# frozen_string_literal: true

RSpec.describe DataPorter::Sources::Json do
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

  let(:import) do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:guests, target_class)
    DataPorter::DataImport.create!(
      target_key: "guests",
      source_type: "json",
      user_type: "User",
      user_id: 1
    )
  end

  after { DataPorter::Registry.clear }

  describe "#fetch" do
    it "parses JSON array content" do
      json = '[{"first_name": "Alice", "last_name": "Smith"}]'
      source = described_class.new(import, content: json)
      records = source.fetch

      expect(records.size).to eq(1)
      expect(records.first[:first_name]).to eq("Alice")
      expect(records.first[:last_name]).to eq("Smith")
    end

    it "transforms keys to parameterized symbols" do
      json = '[{"First Name": "Bob", "Last Name": "Jones"}]'
      source = described_class.new(import, content: json)
      records = source.fetch

      expect(records.first[:first_name]).to eq("Bob")
    end

    it "handles multiple records" do
      json = '[{"first_name": "A"}, {"first_name": "B"}, {"first_name": "C"}]'
      source = described_class.new(import, content: json)

      expect(source.fetch.size).to eq(3)
    end
  end

  describe "#fetch with json_root" do
    let(:target_with_root) do
      Class.new(DataPorter::Target) do
        label "Nested"
        model_name "Nested"
        json_root "data.guests"

        columns do
          column :name, type: :string
        end
      end
    end

    let(:import_with_root) do
      DataPorter::Registry.register(:nested, target_with_root)
      DataPorter::DataImport.create!(
        target_key: "nested",
        source_type: "json",
        user_type: "User",
        user_id: 1
      )
    end

    it "extracts records from a nested path" do
      json = '{"data": {"guests": [{"name": "Alice"}, {"name": "Bob"}]}}'
      source = described_class.new(import_with_root, content: json)
      records = source.fetch

      expect(records.size).to eq(2)
      expect(records.first[:name]).to eq("Alice")
    end
  end

  describe "#fetch with raw_json config" do
    it "reads from config raw_json when no content provided" do
      import.update!(config: { "raw_json" => '[{"first_name": "Config"}]' })
      source = described_class.new(import)
      records = source.fetch

      expect(records.first[:first_name]).to eq("Config")
    end
  end
end
