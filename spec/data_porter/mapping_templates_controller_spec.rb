# frozen_string_literal: true

RSpec.describe DataPorter::MappingTemplatesController do
  describe "inheritance" do
    it "inherits from the configured parent controller" do
      expect(described_class.superclass.name).to eq(DataPorter.configuration.parent_controller)
    end
  end

  describe "action methods" do
    it "defines index, new, create, edit, update, and destroy" do
      actions = %i[index new create edit update destroy]
      actions.each do |action|
        expect(described_class.instance_method(action)).to be_a(UnboundMethod)
      end
    end
  end
end
