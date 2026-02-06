# frozen_string_literal: true

RSpec.describe DataPorter::StoreModels::Error do
  subject(:error) { described_class.new(message: "field is required") }

  it "stores a message" do
    expect(error.message).to eq("field is required")
  end

  it "defaults message to nil" do
    expect(described_class.new.message).to be_nil
  end
end
