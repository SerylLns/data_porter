# frozen_string_literal: true

RSpec.describe DataPorter::Components::Base do
  it "inherits from Phlex::HTML" do
    expect(described_class.superclass).to eq(Phlex::HTML)
  end
end
