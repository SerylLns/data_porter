# frozen_string_literal: true

require "generators/data_porter/install/install_generator"

RSpec.describe DataPorter::Generators::InstallGenerator do
  it "inherits from Rails::Generators::Base" do
    expect(described_class.superclass).to eq(Rails::Generators::Base)
  end

  it "has a source_root pointing to templates" do
    expect(described_class.source_root).to end_with("lib/generators/data_porter/install/templates")
  end

  describe "generator methods" do
    it "defines copy_migration" do
      expect(described_class.instance_method(:copy_migration)).to be_a(UnboundMethod)
    end

    it "defines copy_initializer" do
      expect(described_class.instance_method(:copy_initializer)).to be_a(UnboundMethod)
    end

    it "defines create_importers_directory" do
      expect(described_class.instance_method(:create_importers_directory)).to be_a(UnboundMethod)
    end

    it "defines mount_engine" do
      expect(described_class.instance_method(:mount_engine)).to be_a(UnboundMethod)
    end
  end
end
