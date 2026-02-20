# frozen_string_literal: true

require "spec_helper"
require "generators/data_porter/locale/locale_generator"

RSpec.describe DataPorter::Generators::LocaleGenerator do
  let(:destination) { Dir.mktmpdir }

  after { FileUtils.rm_rf(destination) }

  before do
    allow(described_class).to receive(:source_root).and_return(destination)
  end

  it "is a Rails generator" do
    expect(described_class.superclass).to eq(Rails::Generators::Base)
  end

  it "accepts a locale argument" do
    gen = described_class.new(["de"])
    expect(gen.locale).to eq("de")
  end

  it "defaults locale to en" do
    gen = described_class.new([])
    expect(gen.locale).to eq("en")
  end
end
