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
    it "defines index, new, create, show, parse, confirm, cancel, dry_run, and update_mapping" do
      actions = %i[index new create show parse confirm cancel dry_run update_mapping]
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
end
