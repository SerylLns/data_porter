# frozen_string_literal: true

RSpec.describe DataPorter::ColumnTransformer do
  after { described_class.instance_variable_set(:@custom_transformers, {}) }

  describe ".apply" do
    context "with :strip" do
      it "removes leading and trailing whitespace" do
        expect(described_class.apply("  hello  ", :strip)).to eq("hello")
      end
    end

    context "with :downcase" do
      it "converts to lowercase" do
        expect(described_class.apply("HELLO", :downcase)).to eq("hello")
      end
    end

    context "with :upcase" do
      it "converts to uppercase" do
        expect(described_class.apply("hello", :upcase)).to eq("HELLO")
      end
    end

    context "with :titleize" do
      it "capitalizes first letter of each word" do
        expect(described_class.apply("hello world", :titleize)).to eq("Hello World")
      end
    end

    context "with :normalize_phone" do
      it "removes spaces, dashes, parentheses, and dots" do
        expect(described_class.apply("+1 (555) 123-4567", :normalize_phone)).to eq("+15551234567")
      end
    end

    context "with :parse_date" do
      it "parses date to ISO8601" do
        expect(described_class.apply("January 15, 2024", :parse_date)).to eq("2024-01-15")
      end

      it "returns original value on parse failure" do
        expect(described_class.apply("not-a-date", :parse_date)).to eq("not-a-date")
      end
    end

    context "with :parse_boolean" do
      %w[true 1 yes oui].each do |truthy|
        it "normalizes '#{truthy}' to 'true'" do
          expect(described_class.apply(truthy, :parse_boolean)).to eq("true")
        end
      end

      it "normalizes other values to 'false'" do
        expect(described_class.apply("nope", :parse_boolean)).to eq("false")
      end
    end

    context "with :parse_integer" do
      it "converts to integer string" do
        expect(described_class.apply("42.7", :parse_integer)).to eq("42")
      end

      it "returns original value on failure" do
        expect(described_class.apply("abc", :parse_integer)).to eq("abc")
      end
    end

    context "with :parse_decimal" do
      it "converts to decimal string" do
        expect(described_class.apply("42.7", :parse_decimal)).to eq("42.7")
      end

      it "returns original value on failure" do
        expect(described_class.apply("abc", :parse_decimal)).to eq("abc")
      end
    end

    context "with nil value" do
      it "returns nil without applying transformer" do
        expect(described_class.apply(nil, :strip)).to be_nil
      end
    end

    context "with unknown transformer" do
      it "raises an error" do
        expect { described_class.apply("test", :unknown) }.to raise_error(
          DataPorter::Error, /Unknown transformer: unknown/
        )
      end
    end
  end

  describe ".register" do
    it "registers a custom transformer" do
      described_class.register(:reverse, &:reverse)

      expect(described_class.apply("hello", :reverse)).to eq("olleh")
    end
  end

  describe ".apply_all" do
    it "applies transformers from column definitions to record data" do
      columns = [
        DataPorter::DSL::Column.new(name: :email, transform: %i[strip downcase]),
        DataPorter::DSL::Column.new(name: :name, transform: [])
      ]
      record = DataPorter::StoreModels::ImportRecord.new(
        line_number: 1,
        data: { "email" => "  ALICE@EXAMPLE.COM  ", "name" => "Alice" }
      )

      described_class.apply_all(record, columns)

      expect(record.data["email"]).to eq("alice@example.com")
      expect(record.data["name"]).to eq("Alice")
    end

    it "chains multiple transformers in order" do
      columns = [
        DataPorter::DSL::Column.new(name: :phone, transform: %i[strip normalize_phone])
      ]
      record = DataPorter::StoreModels::ImportRecord.new(
        line_number: 1,
        data: { "phone" => "  +1 (555) 123-4567  " }
      )

      described_class.apply_all(record, columns)

      expect(record.data["phone"]).to eq("+15551234567")
    end

    it "skips columns without transformers" do
      columns = [
        DataPorter::DSL::Column.new(name: :name)
      ]
      record = DataPorter::StoreModels::ImportRecord.new(
        line_number: 1,
        data: { "name" => "Alice" }
      )

      described_class.apply_all(record, columns)

      expect(record.data["name"]).to eq("Alice")
    end
  end
end
