# frozen_string_literal: true

RSpec.describe DataPorter::Sources::Base do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"
    end
  end

  let(:data_import) do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:guests, target_class)
    DataPorter::DataImport.new(target_key: "guests", source_type: "csv")
  end

  describe "#fetch" do
    it "raises NotImplementedError" do
      source = described_class.new(data_import)

      expect { source.fetch }.to raise_error(NotImplementedError)
    end
  end

  describe "#apply_csv_mapping (via subclass)" do
    let(:mapping_target) do
      Class.new(DataPorter::Target) do
        label "Mapped"
        model_name "Mapped"

        csv_mapping do
          map "First Name" => :first_name
          map "Last Name" => :last_name
        end
      end
    end

    let(:auto_target) do
      Class.new(DataPorter::Target) do
        label "Auto"
        model_name "Auto"
      end
    end

    let(:test_source_class) do
      Class.new(described_class) do
        def test_mapping(row)
          apply_csv_mapping(row)
        end
      end
    end

    it "uses explicit csv_mappings when defined" do
      DataPorter::Registry.register(:mapped, mapping_target)
      import = DataPorter::DataImport.new(target_key: "mapped", source_type: "csv")
      source = test_source_class.new(import)
      row = { "First Name" => "Alice", "Last Name" => "Smith" }

      result = source.test_mapping(row)

      expect(result).to eq("first_name" => "Alice", "last_name" => "Smith")
    end

    it "auto-maps headers when no csv_mappings defined" do
      DataPorter::Registry.register(:auto, auto_target)
      import = DataPorter::DataImport.new(target_key: "auto", source_type: "csv")
      source = test_source_class.new(import)
      row = { "First Name" => "Alice", "Email Address" => "alice@example.com" }

      result = source.test_mapping(row)

      expect(result).to eq("first_name" => "Alice", "email_address" => "alice@example.com")
    end

    it "uses user column_mapping from config when present" do
      DataPorter::Registry.register(:mapped, mapping_target)
      import = DataPorter::DataImport.new(target_key: "mapped", source_type: "csv")
      import.config = { "column_mapping" => { "Vorname" => "first_name", "Nachname" => "last_name" } }
      source = test_source_class.new(import)
      row = { "Vorname" => "Hans", "Nachname" => "Mueller" }

      result = source.test_mapping(row)

      expect(result).to eq("first_name" => "Hans", "last_name" => "Mueller")
    end

    it "prioritizes user mapping over code mapping" do
      DataPorter::Registry.register(:mapped, mapping_target)
      import = DataPorter::DataImport.new(target_key: "mapped", source_type: "csv")
      import.config = { "column_mapping" => { "Prenom" => "first_name", "Nom" => "last_name" } }
      source = test_source_class.new(import)
      row = { "Prenom" => "Alice", "Nom" => "Smith" }

      result = source.test_mapping(row)

      expect(result).to eq("first_name" => "Alice", "last_name" => "Smith")
    end
  end
end
