# frozen_string_literal: true

require "csv"
require "tempfile"

RSpec.describe DataPorter::Sources::Csv do
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
    DataPorter::DataImport.new(target_key: "guests", source_type: "csv")
  end

  describe "#fetch" do
    it "parses CSV content and applies mapping" do
      csv_content = "Prenom,Nom,Email\nAlice,Smith,alice@example.com\nBob,Jones,bob@example.com\n"
      source = described_class.new(data_import, content: csv_content)

      rows = source.fetch

      expect(rows.size).to eq(2)
      expect(rows.first).to eq(first_name: "Alice", last_name: "Smith", email: "alice@example.com")
    end

    it "handles empty CSV" do
      csv_content = "Prenom,Nom,Email\n"
      source = described_class.new(data_import, content: csv_content)

      expect(source.fetch).to eq([])
    end

    it "auto-maps when no csv_mapping defined" do
      auto_target = Class.new(DataPorter::Target) do
        label "Auto"
        model_name "Auto"
      end
      DataPorter::Registry.register(:auto, auto_target)
      import = DataPorter::DataImport.new(target_key: "auto", source_type: "csv")
      csv_content = "First Name,Last Name\nAlice,Smith\n"
      source = described_class.new(import, content: csv_content)

      rows = source.fetch

      expect(rows.first).to eq(first_name: "Alice", last_name: "Smith")
    end

    it "handles custom separators via config" do
      import = data_import
      import.config = { "col_sep" => ";" }
      csv_content = "Prenom;Nom;Email\nAlice;Smith;alice@example.com\n"
      source = described_class.new(import, content: csv_content)

      rows = source.fetch

      expect(rows.first[:first_name]).to eq("Alice")
    end
  end
end
