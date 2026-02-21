# frozen_string_literal: true

require "spec_helper"
require "generators/data_porter/views/views_generator"

RSpec.describe DataPorter::Generators::ViewsGenerator do
  include FileUtils

  let(:destination) { Dir.mktmpdir }

  after { rm_rf(destination) }

  describe "default (all views)" do
    before { described_class.start([], destination_root: destination) }

    it "copies imports views" do
      %w[index new show].each do |view|
        path = File.join(destination, "app/views/data_porter/imports/#{view}.html.erb")
        expect(File.exist?(path)).to be(true), "Expected #{view}.html.erb to exist"
      end
    end

    it "copies mapping_templates views" do
      %w[index new edit _form].each do |view|
        path = File.join(destination, "app/views/data_porter/mapping_templates/#{view}.html.erb")
        expect(File.exist?(path)).to be(true), "Expected #{view}.html.erb to exist"
      end
    end

    it "copies the layout" do
      path = File.join(destination, "app/views/layouts/data_porter/application.html.erb")
      expect(File.exist?(path)).to be(true)
    end
  end

  describe "scope: imports" do
    before { described_class.start(%w[imports], destination_root: destination) }

    it "copies only imports views" do
      expect(File.exist?(File.join(destination, "app/views/data_porter/imports/index.html.erb"))).to be(true)
    end

    it "does not copy mapping_templates views" do
      expect(File.exist?(File.join(destination, "app/views/data_porter/mapping_templates/index.html.erb"))).to be(false)
    end

    it "does not copy the layout" do
      expect(File.exist?(File.join(destination, "app/views/layouts/data_porter/application.html.erb"))).to be(false)
    end
  end

  describe "scope: mapping_templates" do
    before { described_class.start(%w[mapping_templates], destination_root: destination) }

    it "copies only mapping_templates views" do
      expect(File.exist?(File.join(destination, "app/views/data_porter/mapping_templates/index.html.erb"))).to be(true)
    end

    it "does not copy imports views" do
      expect(File.exist?(File.join(destination, "app/views/data_porter/imports/index.html.erb"))).to be(false)
    end
  end

  describe "scope: layout" do
    before { described_class.start(%w[layout], destination_root: destination) }

    it "copies only the layout" do
      expect(File.exist?(File.join(destination, "app/views/layouts/data_porter/application.html.erb"))).to be(true)
    end

    it "does not copy imports views" do
      expect(File.exist?(File.join(destination, "app/views/data_porter/imports/index.html.erb"))).to be(false)
    end
  end

  describe "invalid scope" do
    it "raises an error" do
      generator = described_class.new(%w[nonexistent], [], destination_root: destination)

      expect { generator.invoke_all }.to raise_error(Thor::Error, /Unknown scope/)
    end
  end
end
