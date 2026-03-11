# frozen_string_literal: true

RSpec.describe DataPorter::Sources::Xlsx do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"

      columns do
        column :first_name, type: :string, required: true
        column :last_name, type: :string
        column :email, type: :email
      end

      csv_mapping do
        map "Prenom" => :first_name
        map "Nom" => :last_name
        map "Email" => :email
      end
    end
  end

  let(:data_import) do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:guests, target_class)
    DataPorter::DataImport.new(target_key: "guests", source_type: "xlsx")
  end

  let(:fixture_path) { File.expand_path("../../fixtures/contacts.xlsx", __dir__) }

  describe "#headers" do
    it "returns the first row as header strings" do
      source = described_class.new(data_import, file_path: fixture_path)

      expect(source.headers).to eq(%w[Prenom Nom Email])
    end

    it "uses header_row 0 by default (first row)" do
      source = described_class.new(data_import, file_path: fixture_path)

      expect(source.headers).to eq(%w[Prenom Nom Email])
    end
  end

  describe "#fetch" do
    it "parses XLSX content and applies mapping" do
      source = described_class.new(data_import, file_path: fixture_path)

      rows = source.fetch

      expect(rows.size).to eq(2)
      expect(rows.first).to eq("first_name" => "Alice", "last_name" => "Smith", "email" => "alice@example.com")
      expect(rows.last).to eq("first_name" => "Bob", "last_name" => "Jones", "email" => "bob@example.com")
    end

    it "handles empty XLSX (headers only)" do
      empty_path = File.expand_path("../../fixtures/contacts_empty.xlsx", __dir__)
      source = described_class.new(data_import, file_path: empty_path)

      expect(source.fetch).to eq([])
    end

    it "auto-maps when no csv_mapping defined" do
      auto_target = Class.new(DataPorter::Target) do
        label "Auto"
        model_name "Auto"
      end
      DataPorter::Registry.register(:auto, auto_target)
      import = DataPorter::DataImport.new(target_key: "auto", source_type: "xlsx")
      source = described_class.new(import, file_path: fixture_path)

      rows = source.fetch

      expect(rows.first).to eq("prenom" => "Alice", "nom" => "Smith", "email" => "alice@example.com")
    end

    it "selects sheet by index via config" do
      multisheet_path = File.expand_path("../../fixtures/contacts_multisheet.xlsx", __dir__)
      import = data_import
      import.config = { "sheet_index" => 1 }
      source = described_class.new(import, file_path: multisheet_path)

      rows = source.fetch

      expect(rows.size).to eq(1)
      expect(rows.first).to eq("first_name" => "Charlie", "last_name" => "Brown", "email" => "charlie@example.com")
    end
  end
end
