# frozen_string_literal: true

RSpec.describe DataPorter::MappingTemplate, type: :model do
  before { described_class.delete_all }

  describe "validations" do
    it "requires target_key" do
      template = described_class.new(name: "Default", mapping: { "a" => "b" })
      expect(template).not_to be_valid
      expect(template.errors[:target_key]).to include("can't be blank")
    end

    it "requires name" do
      template = described_class.new(target_key: "guests", mapping: { "a" => "b" })
      expect(template).not_to be_valid
      expect(template.errors[:name]).to include("can't be blank")
    end

    it "requires mapping" do
      template = described_class.new(target_key: "guests", name: "Default", mapping: nil)
      expect(template).not_to be_valid
      expect(template.errors[:mapping]).to include("can't be blank")
    end

    it "validates name uniqueness scoped to target_key" do
      described_class.create!(target_key: "guests", name: "Default", mapping: { "a" => "b" })
      duplicate = described_class.new(target_key: "guests", name: "Default", mapping: { "c" => "d" })

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "allows same name for different target_keys" do
      described_class.create!(target_key: "guests", name: "Default", mapping: { "a" => "b" })
      other = described_class.new(target_key: "products", name: "Default", mapping: { "c" => "d" })

      expect(other).to be_valid
    end
  end

  describe ".for_target" do
    it "returns templates for the given target_key" do
      described_class.create!(target_key: "guests", name: "A", mapping: { "a" => "b" })
      described_class.create!(target_key: "guests", name: "B", mapping: { "c" => "d" })
      described_class.create!(target_key: "products", name: "C", mapping: { "e" => "f" })

      results = described_class.for_target("guests")

      expect(results.map(&:name)).to match_array(%w[A B])
    end
  end

  describe "persistence" do
    it "saves and reloads mapping as JSON" do
      template = described_class.create!(
        target_key: "guests",
        name: "French Headers",
        mapping: { "Prenom" => "first_name", "Nom" => "last_name" }
      )

      reloaded = described_class.find(template.id)
      expect(reloaded.mapping).to eq("Prenom" => "first_name", "Nom" => "last_name")
    end
  end
end
