# frozen_string_literal: true

require "generators/data_porter/target/target_generator"

RSpec.describe DataPorter::Generators::TargetGenerator do
  it "inherits from Rails::Generators::NamedBase" do
    expect(described_class.superclass).to eq(Rails::Generators::NamedBase)
  end

  it "has a source_root pointing to templates" do
    expect(described_class.source_root).to end_with("lib/generators/data_porter/target/templates")
  end

  describe "column parsing" do
    let(:generator) { described_class.new(["guests", "first_name:string:required", "email:email"]) }

    it "parses column definitions" do
      columns = generator.send(:parsed_columns)

      expect(columns.size).to eq(2)
      expect(columns[0]).to eq({ name: "first_name", type: "string", required: true })
      expect(columns[1]).to eq({ name: "email", type: "email", required: false })
    end
  end

  describe "naming" do
    let(:generator) { described_class.new(["guests"]) }

    it "derives the class name" do
      expect(generator.send(:target_class_name)).to eq("GuestsTarget")
    end

    it "derives the model name" do
      expect(generator.send(:model_name)).to eq("Guest")
    end

    it "derives the label" do
      expect(generator.send(:target_label)).to eq("Guests")
    end
  end
end
