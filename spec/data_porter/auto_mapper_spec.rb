# frozen_string_literal: true

RSpec.describe DataPorter::AutoMapper do
  let(:target_columns) { %i[email first_name last_name phone_number company] }

  def call(headers, columns = target_columns, custom_synonyms: {})
    described_class.new(headers, columns, custom_synonyms: custom_synonyms).call
  end

  describe "exact match" do
    it "maps normalized header to matching column" do
      result = call(["first_name"])

      expect(result).to eq("first_name" => "first_name")
    end

    it "matches after normalizing spaces and dashes" do
      result = call(["First Name", "last-name"])

      expect(result).to include(
        "First Name" => "first_name",
        "last-name" => "last_name"
      )
    end

    it "strips leading/trailing whitespace" do
      result = call(["  email  "])

      expect(result).to eq("  email  " => "email")
    end
  end

  describe "synonym match" do
    it "maps known synonyms to target columns" do
      result = call(["E-mail Address", "fname", "lname", "tel"])

      expect(result).to eq(
        "E-mail Address" => "email",
        "fname" => "first_name",
        "lname" => "last_name",
        "tel" => "phone_number"
      )
    end

    it "matches case-insensitively" do
      result = call(%w[EMAIL PHONE])

      expect(result).to include(
        "EMAIL" => "email",
        "PHONE" => "phone_number"
      )
    end
  end

  describe "custom synonyms" do
    it "merges custom synonyms with built-in ones" do
      custom = { email: %w[correo] }
      result = call(["correo"], target_columns, custom_synonyms: custom)

      expect(result).to eq("correo" => "email")
    end

    it "custom synonyms do not override built-in ones" do
      custom = { email: %w[correo] }
      result = call(%w[mail correo], target_columns, custom_synonyms: custom)

      expect(result).to include(
        "mail" => "email",
        "correo" => ""
      )
    end
  end

  describe "no duplicates" do
    it "assigns each target column at most once (first match wins)" do
      result = call(["email", "E-mail Address"])

      expect(result).to eq(
        "email" => "email",
        "E-mail Address" => ""
      )
    end
  end

  describe "no match" do
    it "returns empty string for unrecognized headers" do
      result = call(%w[foobar unknown_col])

      expect(result).to eq(
        "foobar" => "",
        "unknown_col" => ""
      )
    end
  end

  describe "normalization edge cases" do
    it "handles special characters" do
      result = call(["(E-mail)"])

      expect(result).to eq("(E-mail)" => "email")
    end

    it "handles empty headers" do
      result = call(["", "email"])

      expect(result).to eq(
        "" => "",
        "email" => "email"
      )
    end

    it "handles nil in headers list" do
      result = call([nil, "email"])

      expect(result).to eq(
        nil => "",
        "email" => "email"
      )
    end
  end

  describe "priority order" do
    it "prefers exact match over synonym match" do
      columns = %i[email mail]
      result = call(["mail"], columns)

      expect(result).to eq("mail" => "mail")
    end
  end
end
