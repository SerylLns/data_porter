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

  describe "#scoped_templates" do
    let(:controller) { described_class.new }

    context "when no scope is configured" do
      it "returns all templates" do
        expect(controller.send(:scoped_templates)).to eq(DataPorter::MappingTemplate.all)
      end
    end

    context "when scope is configured with current_user" do
      let(:user) { User.create! }
      let(:other_user) { User.create! }

      before do
        DataPorter.configuration.scope = ->(u) { u }
        allow(controller).to receive(:current_user).and_return(user)
      end

      after { DataPorter.configuration.scope = nil }

      it "filters templates by owner" do
        mine = DataPorter::MappingTemplate.create!(
          target_key: "test", name: "Mine", mapping: { "a" => "b" }, user: user
        )
        theirs = DataPorter::MappingTemplate.create!(
          target_key: "test", name: "Theirs", mapping: { "a" => "b" }, user: other_user
        )

        result = controller.send(:scoped_templates)

        expect(result).to include(mine)
        expect(result).not_to include(theirs)
      end
    end

    context "when scope is configured but no current_user" do
      before do
        DataPorter.configuration.scope = ->(u) { u }
      end

      after { DataPorter.configuration.scope = nil }

      it "returns all templates" do
        expect(controller.send(:scoped_templates)).to eq(DataPorter::MappingTemplate.all)
      end
    end
  end
end
