# frozen_string_literal: true

RSpec.describe DataPorter::Broadcaster do
  let(:broadcaster) { described_class.new(42) }

  before do
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe "#progress" do
    it "broadcasts processing status with percentage" do
      broadcaster.progress(50, 100)

      expect(ActionCable.server).to have_received(:broadcast).with(
        "data_porter/imports/42",
        { status: :processing, percentage: 50, current: 50, total: 100 }
      )
    end

    it "rounds percentage" do
      broadcaster.progress(1, 3)

      expect(ActionCable.server).to have_received(:broadcast).with(
        "data_porter/imports/42",
        { status: :processing, percentage: 33, current: 1, total: 3 }
      )
    end
  end

  describe "#success" do
    it "broadcasts success status" do
      broadcaster.success

      expect(ActionCable.server).to have_received(:broadcast).with(
        "data_porter/imports/42",
        { status: :success }
      )
    end
  end

  describe "#failure" do
    it "broadcasts failure with error message" do
      broadcaster.failure("Something went wrong")

      expect(ActionCable.server).to have_received(:broadcast).with(
        "data_porter/imports/42",
        { status: :failure, error: "Something went wrong" }
      )
    end
  end

  describe "channel name" do
    it "uses configured cable_channel_prefix" do
      DataPorter.configuration.cable_channel_prefix = "custom"
      custom_broadcaster = described_class.new(99)

      custom_broadcaster.success

      expect(ActionCable.server).to have_received(:broadcast).with(
        "custom/imports/99",
        { status: :success }
      )
    ensure
      DataPorter.configuration.cable_channel_prefix = "data_porter"
    end
  end
end
