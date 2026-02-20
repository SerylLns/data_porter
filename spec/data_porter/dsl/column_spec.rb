# frozen_string_literal: true

RSpec.describe DataPorter::DSL::Column do
  describe "transform" do
    it "defaults to empty array" do
      column = described_class.new(name: :email)

      expect(column.transform).to eq([])
    end

    it "accepts a single transformer as symbol" do
      column = described_class.new(name: :email, transform: :strip)

      expect(column.transform).to eq([:strip])
    end

    it "accepts an array of transformers" do
      column = described_class.new(name: :email, transform: %i[strip downcase])

      expect(column.transform).to eq(%i[strip downcase])
    end
  end
end
