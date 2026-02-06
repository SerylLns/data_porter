# frozen_string_literal: true

RSpec.describe DataPorter::Engine do
  it "is a Rails::Engine" do
    expect(described_class.superclass).to eq(Rails::Engine)
  end

  it "has an isolated namespace" do
    expect(described_class.isolated?).to be true
  end

  it "is namespaced under DataPorter" do
    expect(described_class.engine_name).to eq("data_porter")
  end
end
