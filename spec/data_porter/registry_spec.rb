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
          sources: DataPorter.configuration.enabled_sources, params: [] },
        { key: :products, label: "Products", icon: "fas fa-box",
          sources: DataPorter.configuration.enabled_sources, params: [] }
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

    context "when target declares params" do
      let(:params_target) do
        Class.new(DataPorter::Target) do
          label "Hotels"
          model_name "Hotel"
          icon "fas fa-hotel"

          params do
            param :region, type: :select, label: "Region", required: true,
                           collection: -> { [%w[EU eu], %w[US us]] }
            param :currency, type: :text, default: "EUR"
          end
        end
      end

      it "includes serialized params" do
        described_class.register(:hotels, params_target)

        result = described_class.available.find { |t| t[:key] == :hotels }

        expect(result[:params].size).to eq(2)
      end

      it "serializes param attributes" do
        described_class.register(:hotels, params_target)

        result = described_class.available.find { |t| t[:key] == :hotels }
        region = result[:params].first

        expect(region[:name]).to eq(:region)
        expect(region[:type]).to eq(:select)
        expect(region[:required]).to be true
        expect(region[:label]).to eq("Region")
      end

      it "evaluates collection lambdas at call time" do
        described_class.register(:hotels, params_target)

        result = described_class.available.find { |t| t[:key] == :hotels }
        region = result[:params].first

        expect(region[:collection]).to eq([%w[EU eu], %w[US us]])
      end

      it "accepts collection as a plain array" do
        array_target = Class.new(DataPorter::Target) do
          label "ArrayParams"
          model_name "ArrayParam"
          icon "fas fa-list"

          params do
            param :status, type: :select, collection: [%w[Active active], %w[Archived archived]]
          end
        end
        described_class.register(:array_params, array_target)

        result = described_class.available.find { |t| t[:key] == :array_params }

        expect(result[:params].first[:collection]).to eq([%w[Active active], %w[Archived archived]])
      end

      it "includes default values" do
        described_class.register(:hotels, params_target)

        result = described_class.available.find { |t| t[:key] == :hotels }
        currency = result[:params].last

        expect(currency[:default]).to eq("EUR")
      end
    end

    context "when target does not declare params" do
      it "returns empty params array" do
        described_class.register(:guests, target_class)

        result = described_class.available.find { |t| t[:key] == :guests }

        expect(result[:params]).to eq([])
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
