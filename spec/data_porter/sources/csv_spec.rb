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

  describe "#headers" do
    it "returns the first row as header strings" do
      csv_content = "Prenom,Nom,Email\nAlice,Smith,alice@example.com\n"
      source = described_class.new(data_import, content: csv_content)

      expect(source.headers).to eq(%w[Prenom Nom Email])
    end

    it "handles custom separators via config" do
      import = data_import
      import.config = { "col_sep" => ";" }
      csv_content = "Prenom;Nom;Email\nAlice;Smith;alice@example.com\n"
      source = described_class.new(import, content: csv_content)

      expect(source.headers).to eq(%w[Prenom Nom Email])
    end

    it "auto-detects semicolon separator" do
      csv_content = "Prenom;Nom;Email\nAlice;Smith;alice@example.com\n"
      source = described_class.new(data_import, content: csv_content)

      expect(source.headers).to eq(%w[Prenom Nom Email])
    end

    it "auto-detects tab separator" do
      csv_content = "Prenom\tNom\tEmail\nAlice\tSmith\talice@example.com\n"
      source = described_class.new(data_import, content: csv_content)

      expect(source.headers).to eq(%w[Prenom Nom Email])
    end

    it "handles Latin-1 encoded content" do
      csv_content = "Prénom,Nom\nAlice,Müller\n".encode("ISO-8859-1")
      source = described_class.new(data_import, content: csv_content)

      expect(source.headers).to eq(%w[Prénom Nom])
    end

    it "strips UTF-8 BOM" do
      csv_content = "\xEF\xBB\xBFPrenom,Nom,Email\nAlice,Smith,a@b.com\n"
      source = described_class.new(data_import, content: csv_content)

      expect(source.headers).to eq(%w[Prenom Nom Email])
    end

    it "returns empty array when header row is entirely blank" do
      csv_content = ",,,\nAlice,Smith,alice@example.com,extra\n"
      source = described_class.new(data_import, content: csv_content)

      expect(source.headers).to eq([])
    end

    it "skips leading rows when header_row is set in config" do
      import = data_import
      import.config = { "header_row" => 2 }
      csv_content = "notes\n*required,*required\nPrenom,Nom,Email\nAlice,Smith,alice@example.com\n"
      source = described_class.new(import, content: csv_content)

      expect(source.headers).to eq(%w[Prenom Nom Email])
    end

    it "skips leading rows when header_row is set on target" do
      target_with_offset = Class.new(DataPorter::Target) do
        label "Offset"
        model_name "Offset"
        header_row 2
      end
      DataPorter::Registry.register(:offset, target_with_offset)
      import = DataPorter::DataImport.new(target_key: "offset", source_type: "csv")
      csv_content = "notes\n*required,*required\nFirst Name,Last Name\nAlice,Smith\n"
      source = described_class.new(import, content: csv_content)

      expect(source.headers).to eq(["First Name", "Last Name"])
    end
  end

  describe "#fetch" do
    it "parses CSV content and applies mapping" do
      csv_content = "Prenom,Nom,Email\nAlice,Smith,alice@example.com\nBob,Jones,bob@example.com\n"
      source = described_class.new(data_import, content: csv_content)

      rows = source.fetch

      expect(rows.size).to eq(2)
      expect(rows.first).to eq("first_name" => "Alice", "last_name" => "Smith", "email" => "alice@example.com")
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

      expect(rows.first).to eq("first_name" => "Alice", "last_name" => "Smith")
    end

    it "handles custom separators via config" do
      import = data_import
      import.config = { "col_sep" => ";" }
      csv_content = "Prenom;Nom;Email\nAlice;Smith;alice@example.com\n"
      source = described_class.new(import, content: csv_content)

      rows = source.fetch

      expect(rows.first["first_name"]).to eq("Alice")
    end

    it "auto-detects semicolon separator for fetch" do
      csv_content = "Prenom;Nom;Email\nAlice;Smith;alice@example.com\n"
      source = described_class.new(data_import, content: csv_content)

      rows = source.fetch

      expect(rows.first["first_name"]).to eq("Alice")
    end

    it "auto-detects tab separator for fetch" do
      csv_content = "Prenom\tNom\tEmail\nAlice\tSmith\talice@example.com\n"
      source = described_class.new(data_import, content: csv_content)

      rows = source.fetch

      expect(rows.first["first_name"]).to eq("Alice")
    end

    it "skips leading rows when header_row is set" do
      import = data_import
      import.config = { "header_row" => 2 }
      csv_content = "notes\ndescription line\nPrenom,Nom,Email\n" \
                    "Alice,Smith,alice@example.com\nBob,Jones,bob@example.com\n"
      source = described_class.new(import, content: csv_content)

      rows = source.fetch

      expect(rows.size).to eq(2)
      expect(rows.first).to eq("first_name" => "Alice", "last_name" => "Smith", "email" => "alice@example.com")
    end

    it "transcodes Latin-1 content to UTF-8 for fetch" do
      csv_content = "Prenom,Nom,Email\nRené,Müller,r@b.com\n".encode("ISO-8859-1")
      source = described_class.new(data_import, content: csv_content)

      rows = source.fetch

      expect(rows.first["first_name"]).to eq("René")
    end
  end
end
