# frozen_string_literal: true

RSpec.describe DataPorter::ImportsController do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Test Import"
      icon "fas fa-test"
      model_name "TestModel"

      columns do
        column :name, type: :string, required: true
      end
    end
  end

  before do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:test_import, target_class)
  end

  after { DataPorter::Registry.clear }

  describe "inheritance" do
    it "inherits from the configured parent controller" do
      expect(described_class.superclass.name).to eq(DataPorter.configuration.parent_controller)
    end
  end

  describe "before_actions" do
    it "registers set_import callback" do
      callbacks = described_class._process_action_callbacks.select do |c|
        c.filter == :set_import
      end

      expect(callbacks).not_to be_empty
    end
  end

  describe "action methods" do
    it "defines index, new, create, show, parse, confirm, cancel, dry_run, update_mapping, status, and destroy" do
      actions = %i[index new create show parse confirm cancel dry_run update_mapping status destroy]
      actions.each do |action|
        expect(described_class.instance_method(action)).to be_a(UnboundMethod)
      end
    end
  end

  describe "private methods" do
    it "defines set_import" do
      expect(described_class.private_instance_methods).to include(:set_import)
    end

    it "defines import_params" do
      expect(described_class.private_instance_methods).to include(:import_params)
    end

    it "defines valid_file_presence?" do
      expect(described_class.private_instance_methods).to include(:valid_file_presence?)
    end

    it "defines valid_source_for_target?" do
      expect(described_class.private_instance_methods).to include(:valid_source_for_target?)
    end

    it "defines valid_import_params?" do
      expect(described_class.private_instance_methods).to include(:valid_import_params?)
    end
  end

  describe "#paginate_records" do
    let(:controller) { described_class.new }
    let(:records) { (1..75).map { |i| DataPorter::StoreModels::ImportRecord.new(line_number: i) } }

    before { controller.instance_variable_set(:@records, records) }

    it "defaults to page 1 with 50 per page" do
      controller.params = ActionController::Parameters.new({})
      controller.send(:paginate_records)

      expect(controller.instance_variable_get(:@records).size).to eq(50)
      expect(controller.instance_variable_get(:@page)).to eq(1)
      expect(controller.instance_variable_get(:@total_pages)).to eq(2)
    end

    it "returns second page records" do
      controller.params = ActionController::Parameters.new(page: "2")
      controller.send(:paginate_records)

      expect(controller.instance_variable_get(:@records).size).to eq(25)
      expect(controller.instance_variable_get(:@page)).to eq(2)
    end

    it "clamps page to valid range" do
      controller.params = ActionController::Parameters.new(page: "999")
      controller.send(:paginate_records)

      expect(controller.instance_variable_get(:@page)).to eq(2)
    end

    it "skips pagination when records fit in one page" do
      controller.instance_variable_set(:@records, records.first(10))
      controller.params = ActionController::Parameters.new({})
      controller.send(:paginate_records)

      expect(controller.instance_variable_get(:@total_pages)).to eq(1)
    end
  end

  describe "#valid_file_presence?" do
    let(:controller) { described_class.new }

    before { controller.instance_variable_set(:@import, import) }

    context "with csv source and no file" do
      let(:import) { DataPorter::DataImport.new(source_type: "csv") }

      it "returns false" do
        expect(controller.send(:valid_file_presence?)).to be false
      end

      it "adds error message" do
        controller.send(:valid_file_presence?)
        expect(import.errors[:file]).to include("must be attached for CSV imports")
      end
    end

    context "with json source and no file" do
      let(:import) { DataPorter::DataImport.new(source_type: "json") }

      it "returns false" do
        expect(controller.send(:valid_file_presence?)).to be false
      end
    end

    context "with xlsx source and no file" do
      let(:import) { DataPorter::DataImport.new(source_type: "xlsx") }

      it "returns false" do
        expect(controller.send(:valid_file_presence?)).to be false
      end
    end

    context "with api source and no file" do
      let(:import) { DataPorter::DataImport.new(source_type: "api") }

      it "returns true" do
        expect(controller.send(:valid_file_presence?)).to be true
      end
    end
  end

  describe "#valid_source_for_target?" do
    let(:controller) { described_class.new }
    let(:csv_only_target) do
      Class.new(DataPorter::Target) do
        label "CsvOnly"
        model_name "CsvOnly"
        sources :csv
      end
    end

    before do
      DataPorter::Registry.clear
      DataPorter::Registry.register(:csv_only, csv_only_target)
    end

    context "when source is allowed by target" do
      let(:import) { DataPorter::DataImport.new(target_key: "csv_only", source_type: "csv") }

      before { controller.instance_variable_set(:@import, import) }

      it "returns true" do
        expect(controller.send(:valid_source_for_target?)).to be true
      end
    end

    context "when source is not allowed by target" do
      let(:import) { DataPorter::DataImport.new(target_key: "csv_only", source_type: "xlsx") }

      before { controller.instance_variable_set(:@import, import) }

      it "returns false" do
        expect(controller.send(:valid_source_for_target?)).to be false
      end

      it "adds an error message" do
        controller.send(:valid_source_for_target?)

        expect(import.errors[:source_type]).to include("xlsx is not available for this target")
      end
    end

    context "when target has no sources declared" do
      let(:no_sources_target) do
        Class.new(DataPorter::Target) do
          label "NoSources"
          model_name "NoSources"
        end
      end
      let(:import) { DataPorter::DataImport.new(target_key: "no_sources", source_type: "xlsx") }

      before do
        DataPorter::Registry.register(:no_sources, no_sources_target)
        controller.instance_variable_set(:@import, import)
      end

      it "allows any enabled source" do
        expect(controller.send(:valid_source_for_target?)).to be true
      end
    end
  end

  describe "#valid_import_params?" do
    let(:controller) { described_class.new }

    context "when target has required params" do
      let(:params_target) do
        Class.new(DataPorter::Target) do
          label "WithParams"
          model_name "WithParams"

          params do
            param :hotel_id, type: :select, required: true
            param :currency, type: :text
          end
        end
      end

      before do
        DataPorter::Registry.register(:with_params, params_target)
      end

      context "when required param is present" do
        let(:import) do
          DataPorter::DataImport.new(
            target_key: "with_params",
            config: { "import_params" => { "hotel_id" => "42" } }
          )
        end

        before { controller.instance_variable_set(:@import, import) }

        it "returns true" do
          expect(controller.send(:valid_import_params?)).to be true
        end
      end

      context "when required param is missing" do
        let(:import) do
          DataPorter::DataImport.new(
            target_key: "with_params",
            config: { "import_params" => {} }
          )
        end

        before { controller.instance_variable_set(:@import, import) }

        it "returns false" do
          expect(controller.send(:valid_import_params?)).to be false
        end

        it "adds an error" do
          controller.send(:valid_import_params?)

          expect(import.errors[:base]).to include("Hotel is required")
        end
      end

      context "when required param is blank" do
        let(:import) do
          DataPorter::DataImport.new(
            target_key: "with_params",
            config: { "import_params" => { "hotel_id" => "" } }
          )
        end

        before { controller.instance_variable_set(:@import, import) }

        it "returns false" do
          expect(controller.send(:valid_import_params?)).to be false
        end
      end
    end

    context "when target has no params" do
      let(:import) { DataPorter::DataImport.new(target_key: "test_import") }

      before { controller.instance_variable_set(:@import, import) }

      it "returns true" do
        expect(controller.send(:valid_import_params?)).to be true
      end
    end
  end

  describe "#merge_import_params" do
    let(:controller) { described_class.new }
    let(:params_target) do
      Class.new(DataPorter::Target) do
        label "WithParams"
        model_name "WithParams"

        params do
          param :hotel_id, type: :select, required: true
          param :currency, type: :text
        end
      end
    end

    before do
      DataPorter::Registry.register(:with_params, params_target)
    end

    it "permits declared param names" do
      raw = ActionController::Parameters.new(
        data_import: {
          target_key: "with_params",
          source_type: "csv",
          config: { import_params: { hotel_id: "42", currency: "EUR" } }
        }
      )
      controller.params = raw
      permitted = raw.require(:data_import).permit(:target_key, :source_type, :file, config: {})
      result = controller.send(:merge_import_params, permitted)

      expect(result[:config]["import_params"].keys).to contain_exactly("hotel_id", "currency")
      expect(result[:config]["import_params"]["hotel_id"]).to eq("42")
      expect(result[:config]["import_params"]["currency"]).to eq("EUR")
    end

    it "strips undeclared param names" do
      raw = ActionController::Parameters.new(
        data_import: {
          target_key: "with_params",
          source_type: "csv",
          config: { import_params: { hotel_id: "42", injected: "malicious" } }
        }
      )
      controller.params = raw
      permitted = raw.require(:data_import).permit(:target_key, :source_type, :file, config: {})
      result = controller.send(:merge_import_params, permitted)

      expect(result[:config]["import_params"].keys).to eq(["hotel_id"])
      expect(result[:config]["import_params"]).not_to have_key("injected")
    end

    it "returns permitted unchanged when no import_params present" do
      raw = ActionController::Parameters.new(
        data_import: { target_key: "with_params", source_type: "csv" }
      )
      controller.params = raw
      permitted = raw.require(:data_import).permit(:target_key, :source_type, :file, config: {})
      result = controller.send(:merge_import_params, permitted)

      expect(result[:config]).to be_nil
    end
  end

  describe "#permitted_column_mapping" do
    let(:controller) { described_class.new }
    let(:import) do
      DataPorter::DataImport.new(target_key: "test_import", source_type: "csv")
    end

    before { controller.instance_variable_set(:@import, import) }

    it "allows valid target column names as values" do
      controller.params = ActionController::Parameters.new(
        column_mapping: { "Name" => "name", "Other" => "" }
      )
      result = controller.send(:permitted_column_mapping)

      expect(result).to eq("Name" => "name", "Other" => "")
    end

    it "rejects values that are not valid target column names" do
      controller.params = ActionController::Parameters.new(
        column_mapping: { "Name" => "name", "Injected" => "admin_role" }
      )
      result = controller.send(:permitted_column_mapping)

      expect(result).to eq("Name" => "name", "Injected" => "")
    end
  end
end
