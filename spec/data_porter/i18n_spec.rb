# frozen_string_literal: true

require "spec_helper"

RSpec.describe "I18n" do
  let(:en) { YAML.load_file(File.expand_path("../../config/locales/en.yml", __dir__)) }
  let(:fr) { YAML.load_file(File.expand_path("../../config/locales/fr.yml", __dir__)) }

  def flatten_keys(hash, prefix = "")
    hash.each_with_object([]) do |(key, value), keys|
      full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      if value.is_a?(Hash)
        keys.concat(flatten_keys(value, full_key))
      else
        keys << full_key
      end
    end
  end

  it "loads English locale" do
    expect(I18n.t("data_porter.imports.title", locale: :en)).to eq("Imports")
  end

  it "loads French locale" do
    expect(I18n.t("data_porter.imports.title", locale: :fr)).to eq("Imports")
  end

  it "has all English keys present in French" do
    en_keys = flatten_keys(en["en"]["data_porter"])
    fr_keys = flatten_keys(fr["fr"]["data_porter"])
    missing = en_keys - fr_keys
    expect(missing).to be_empty, "Missing FR keys: #{missing.join(", ")}"
  end

  it "has all French keys present in English" do
    en_keys = flatten_keys(en["en"]["data_porter"])
    fr_keys = flatten_keys(fr["fr"]["data_porter"])
    extra = fr_keys - en_keys
    expect(extra).to be_empty, "Extra FR keys: #{extra.join(", ")}"
  end

  it "has no empty values in English locale" do
    en_values = flatten_values(en["en"]["data_porter"])
    empty = en_values.select { |_, v| v.to_s.strip.empty? }
    expect(empty).to be_empty, "Empty EN values: #{empty.keys.join(", ")}"
  end

  it "has no empty values in French locale" do
    fr_values = flatten_values(fr["fr"]["data_porter"])
    empty = fr_values.select { |_, v| v.to_s.strip.empty? }
    expect(empty).to be_empty, "Empty FR values: #{empty.keys.join(", ")}"
  end

  describe "components" do
    it "translates status badge labels" do
      %w[pending completed failed importing].each do |status|
        expect(I18n.t("data_porter.components.status_badge.#{status}",
                      locale: :en)).not_to include("translation missing")
        expect(I18n.t("data_porter.components.status_badge.#{status}",
                      locale: :fr)).not_to include("translation missing")
      end
    end

    it "translates progress labels" do
      %w[waiting parsing importing dry_running].each do |status|
        expect(I18n.t("data_porter.components.progress.#{status}", locale: :en)).not_to include("translation missing")
      end
    end

    it "translates summary card labels" do
      %w[ready incomplete missing duplicates].each do |label|
        expect(I18n.t("data_porter.components.summary_cards.#{label}",
                      locale: :en)).not_to include("translation missing")
      end
    end
  end

  describe "error messages" do
    it "translates validation errors with interpolation" do
      msg = I18n.t("data_porter.errors.required", label: "Email", locale: :en)
      expect(msg).to eq("Email is required")
    end

    it "translates max records error with interpolation" do
      msg = I18n.t("data_porter.errors.max_records", count: 15_000, max: 10_000, locale: :en)
      expect(msg).to eq("File contains 15000 records, exceeds maximum of 10000")
    end

    it "translates French validation errors" do
      msg = I18n.t("data_porter.errors.required", label: "Email", locale: :fr)
      expect(msg).to eq("Email est requis")
    end
  end

  private

  def flatten_values(hash, prefix = "")
    hash.each_with_object({}) do |(key, value), result|
      full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      if value.is_a?(Hash)
        result.merge!(flatten_values(value, full_key))
      else
        result[full_key] = value
      end
    end
  end
end
