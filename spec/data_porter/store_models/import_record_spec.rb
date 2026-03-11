# frozen_string_literal: true

RSpec.describe DataPorter::StoreModels::ImportRecord do
  subject(:record) { described_class.new(line_number: 1, data: { name: "Alice" }) }

  describe "defaults" do
    it "defaults status to pending" do
      expect(record.status).to eq("pending")
    end

    it "defaults errors_list to empty" do
      expect(record.errors_list).to eq([])
    end

    it "defaults warnings to empty" do
      expect(record.warnings).to eq([])
    end

    it "defaults dry_run_passed to false" do
      expect(record.dry_run_passed).to be false
    end
  end

  describe "#add_error" do
    it "appends an error to errors_list" do
      record.add_error("name is required")

      expect(record.errors_list.size).to eq(1)
      expect(record.errors_list.first.message).to eq("name is required")
    end
  end

  describe "#add_warning" do
    it "appends a warning" do
      record.add_warning("no email provided")

      expect(record.warnings.size).to eq(1)
      expect(record.warnings.first.message).to eq("no email provided")
    end
  end

  describe "#complete?" do
    it "returns true when status is complete" do
      record.status = "complete"
      expect(record.complete?).to be true
    end

    it "returns false otherwise" do
      expect(record.complete?).to be false
    end
  end

  describe "#importable?" do
    it "returns true when status is complete" do
      record.status = "complete"
      expect(record.importable?).to be true
    end
  end

  describe "#attributes" do
    it "returns compact data with string keys" do
      record = described_class.new(data: { "name" => "Alice", "email" => nil })

      expect(record.attributes).to eq({ "name" => "Alice" })
    end
  end

  describe "#determine_status!" do
    it "sets missing when required field error exists" do
      record.add_error("Name is required")
      record.determine_status!

      expect(record.status).to eq("missing")
    end

    it "sets partial when non-required error exists" do
      record.add_error("Email: invalid email")
      record.determine_status!

      expect(record.status).to eq("partial")
    end

    it "sets complete when no errors" do
      record.determine_status!

      expect(record.status).to eq("complete")
    end
  end
end
