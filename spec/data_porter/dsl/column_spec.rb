# frozen_string_literal: true

RSpec.describe DataPorter::DSL::Column do
  describe "synonyms" do
    it "defaults to empty array" do
      column = described_class.new(name: :email)

      expect(column.synonyms).to eq([])
    end

    it "accepts an array of synonyms" do
      column = described_class.new(name: :email, synonyms: %w[correo adresse_email])

      expect(column.synonyms).to eq(%w[correo adresse_email])
    end
  end

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
