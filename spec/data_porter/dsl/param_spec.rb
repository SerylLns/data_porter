# frozen_string_literal: true

RSpec.describe DataPorter::DSL::Param do
  describe "defaults" do
    subject(:param) { described_class.new(name: :hotel_id) }

    it "sets name as symbol" do
      expect(param.name).to eq(:hotel_id)
    end

    it "defaults type to :text" do
      expect(param.type).to eq(:text)
    end

    it "defaults required to false" do
      expect(param.required).to be false
    end

    it "defaults label to humanized name" do
      expect(param.label).to eq("Hotel")
    end

    it "defaults collection to nil" do
      expect(param.collection).to be_nil
    end

    it "defaults default to nil" do
      expect(param.default).to be_nil
    end
  end

  describe "custom values" do
    subject(:param) do
      described_class.new(
        name: :hotel_id,
        type: :select,
        required: true,
        label: "Hotel",
        collection: -> { [%w[Hilton 1]] },
        default: "1"
      )
    end

    it "stores the type" do
      expect(param.type).to eq(:select)
    end

    it "stores required flag" do
      expect(param.required).to be true
    end

    it "stores custom label" do
      expect(param.label).to eq("Hotel")
    end

    it "stores the collection callable" do
      expect(param.collection.call).to eq([%w[Hilton 1]])
    end

    it "stores the default value" do
      expect(param.default).to eq("1")
    end
  end

  describe "type validation" do
    it "accepts :select" do
      expect { described_class.new(name: :x, type: :select) }.not_to raise_error
    end

    it "accepts :text" do
      expect { described_class.new(name: :x, type: :text) }.not_to raise_error
    end

    it "accepts :number" do
      expect { described_class.new(name: :x, type: :number) }.not_to raise_error
    end

    it "accepts :hidden" do
      expect { described_class.new(name: :x, type: :hidden) }.not_to raise_error
    end

    it "rejects invalid types" do
      expect { described_class.new(name: :x, type: :checkbox) }
        .to raise_error(ArgumentError, /invalid param type: checkbox/)
    end
  end

  describe "extra options" do
    it "stores extra keyword arguments" do
      param = described_class.new(name: :x, placeholder: "Enter value")

      expect(param.options).to eq(placeholder: "Enter value")
    end
  end
end
