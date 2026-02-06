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
    it "defines index, new, create, show, parse, confirm, cancel, and dry_run" do
      actions = %i[index new create show parse confirm cancel dry_run]
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
  end
end
