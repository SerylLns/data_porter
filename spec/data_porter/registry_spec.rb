# frozen_string_literal: true

RSpec.describe DataPorter::Registry do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"
      icon "fas fa-users"
    end
  end

  let(:another_target) do
    Class.new(DataPorter::Target) do
      label "Products"
      model_name "Product"
      icon "fas fa-box"
    end
  end

  before { described_class.clear }

  describe ".register" do
    it "stores a target by key" do
      described_class.register(:guests, target_class)

      expect(described_class.find(:guests)).to eq(target_class)
    end
  end

  describe ".find" do
    it "returns the registered target class" do
      described_class.register(:guests, target_class)

      expect(described_class.find(:guests)).to eq(target_class)
    end

    it "accepts string keys" do
      described_class.register(:guests, target_class)

      expect(described_class.find("guests")).to eq(target_class)
    end

    it "raises TargetNotFound for unknown keys" do
      expect { described_class.find(:unknown) }.to raise_error(DataPorter::TargetNotFound)
    end
  end

  describe ".available" do
    it "returns an array of target summaries" do
      described_class.register(:guests, target_class)
      described_class.register(:products, another_target)

      result = described_class.available

      expect(result).to contain_exactly(
        { key: :guests, label: "Guests", icon: "fas fa-users",
          sources: DataPorter.configuration.enabled_sources },
        { key: :products, label: "Products", icon: "fas fa-box",
          sources: DataPorter.configuration.enabled_sources }
      )
    end

    it "returns empty array when no targets registered" do
      expect(described_class.available).to eq([])
    end

    context "when target declares sources" do
      let(:csv_only_target) do
        Class.new(DataPorter::Target) do
          label "CsvOnly"
          model_name "CsvOnly"
          icon "fas fa-file"
          sources :csv
        end
      end

      it "includes the target-specific sources" do
        described_class.register(:csv_only, csv_only_target)

        result = described_class.available.find { |t| t[:key] == :csv_only }

        expect(result[:sources]).to eq(%i[csv])
      end
    end

    context "when target does not declare sources" do
      it "falls back to global enabled_sources" do
        described_class.register(:guests, target_class)

        result = described_class.available.find { |t| t[:key] == :guests }

        expect(result[:sources]).to eq(DataPorter.configuration.enabled_sources)
      end
    end
  end

  describe ".refresh!" do
    it "clears existing registrations" do
      described_class.register(:guests, target_class)
      described_class.refresh!

      expect(described_class.available).to eq([])
    end
  end

  describe ".clear" do
    it "removes all registered targets" do
      described_class.register(:guests, target_class)
      described_class.clear

      expect(described_class.available).to eq([])
    end
  end
end
