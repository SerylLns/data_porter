# frozen_string_literal: true

RSpec.describe DataPorter::TypeValidator do
  describe ".valid?" do
    context "with :string type" do
      it "accepts any string" do
        expect(described_class.valid?("hello", :string)).to be true
      end
    end

    context "with :integer type" do
      it "accepts valid integers" do
        expect(described_class.valid?("42", :integer)).to be true
      end

      it "rejects non-integers" do
        expect(described_class.valid?("abc", :integer)).to be false
      end
    end

    context "with :decimal type" do
      it "accepts valid decimals" do
        expect(described_class.valid?("3.14", :decimal)).to be true
      end

      it "rejects non-decimals" do
        expect(described_class.valid?("xyz", :decimal)).to be false
      end
    end

    context "with :date type" do
      it "accepts valid dates" do
        expect(described_class.valid?("2024-01-15", :date)).to be true
      end

      it "accepts dates with custom format" do
        expect(described_class.valid?("15/01/2024", :date, format: "%d/%m/%Y")).to be true
      end

      it "rejects invalid dates" do
        expect(described_class.valid?("not-a-date", :date)).to be false
      end
    end

    context "with :datetime type" do
      it "accepts valid datetimes" do
        expect(described_class.valid?("2024-01-15T10:30:00", :datetime)).to be true
      end

      it "rejects invalid datetimes" do
        expect(described_class.valid?("nope", :datetime)).to be false
      end
    end

    context "with :email type" do
      it "accepts valid emails" do
        expect(described_class.valid?("user@example.com", :email)).to be true
      end

      it "rejects invalid emails" do
        expect(described_class.valid?("not-an-email", :email)).to be false
      end
    end

    context "with :phone type" do
      it "accepts valid phone numbers" do
        expect(described_class.valid?("+33612345678", :phone)).to be true
      end

      it "rejects clearly invalid phones" do
        expect(described_class.valid?("abc", :phone)).to be false
      end
    end

    context "with :url type" do
      it "accepts valid URLs" do
        expect(described_class.valid?("https://example.com", :url)).to be true
      end

      it "rejects URLs without scheme" do
        expect(described_class.valid?("example.com", :url)).to be false
      end
    end

    context "with :boolean type" do
      it "accepts true values" do
        %w[true 1].each do |val|
          expect(described_class.valid?(val, :boolean)).to be true
        end
      end

      it "accepts false values" do
        %w[false 0].each do |val|
          expect(described_class.valid?(val, :boolean)).to be true
        end
      end

      it "rejects non-boolean values" do
        expect(described_class.valid?("maybe", :boolean)).to be false
      end
    end
  end
end
