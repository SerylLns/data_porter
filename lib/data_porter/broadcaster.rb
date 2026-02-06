# frozen_string_literal: true

module DataPorter
  class Broadcaster
    def initialize(import_id)
      prefix = DataPorter.configuration.cable_channel_prefix
      @channel = "#{prefix}/imports/#{import_id}"
    end

    def progress(current, total)
      percentage = ((current.to_f / total) * 100).round
      broadcast(status: :processing, percentage: percentage, current: current, total: total)
    end

    def success
      broadcast(status: :success)
    end

    def failure(message)
      broadcast(status: :failure, error: message)
    end

    private

    def broadcast(message)
      ActionCable.server.broadcast(@channel, message)
    end
  end
end
