# frozen_string_literal: true

require "spec_helper"
require "generators/data_porter/target/target_generator"

RSpec.describe DataPorter::Generators::TargetGenerator do
  include FileUtils

  let(:destination) { Dir.mktmpdir }

  before { described_class.start(args, destination_root: destination) }

  after { rm_rf(destination) }

  describe "default sources" do
    let(:args) { %w[product name:string] }

    it "generates sources :csv by default" do
      content = File.read(File.join(destination, "app/importers/product_target.rb"))

      expect(content).to include("sources :csv")
    end
  end

  describe "--sources option" do
    let(:args) { %w[product name:string --sources csv xlsx] }

    it "generates sources with specified types" do
      content = File.read(File.join(destination, "app/importers/product_target.rb"))

      expect(content).to include("sources :csv, :xlsx")
    end
  end

  describe "--sources with all types" do
    let(:args) { %w[order name:string --sources csv xlsx api json] }

    it "generates sources with all specified types" do
      content = File.read(File.join(destination, "app/importers/order_target.rb"))

      expect(content).to include("sources :csv, :xlsx, :api, :json")
    end
  end
end
