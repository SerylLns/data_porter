# frozen_string_literal: true

RSpec.describe DataPorter::Configuration do
  subject(:config) { described_class.new }

  it "has default parent_controller" do
    expect(config.parent_controller).to eq("ApplicationController")
  end

  it "has default queue_name" do
    expect(config.queue_name).to eq(:imports)
  end

  it "has default storage_service" do
    expect(config.storage_service).to eq(:local)
  end

  it "has default cable_channel_prefix" do
    expect(config.cable_channel_prefix).to eq("data_porter")
  end

  it "has nil context_builder by default" do
    expect(config.context_builder).to be_nil
  end

  it "has default preview_limit" do
    expect(config.preview_limit).to eq(500)
  end

  it "has default enabled_sources" do
    expect(config.enabled_sources).to eq(%i[csv json api xlsx])
  end

  it "has nil scope by default" do
    expect(config.scope).to be_nil
  end
end

RSpec.describe DataPorter do
  describe ".configure" do
    after { DataPorter.instance_variable_set(:@configuration, nil) }

    it "yields the configuration" do
      DataPorter.configure do |config|
        config.queue_name = :custom_queue
      end

      expect(DataPorter.configuration.queue_name).to eq(:custom_queue)
    end
  end

  describe ".configuration" do
    after { DataPorter.instance_variable_set(:@configuration, nil) }

    it "returns a Configuration instance" do
      expect(DataPorter.configuration).to be_a(DataPorter::Configuration)
    end

    it "memoizes the configuration" do
      expect(DataPorter.configuration).to be(DataPorter.configuration)
    end
  end
end
