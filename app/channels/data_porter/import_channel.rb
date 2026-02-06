# frozen_string_literal: true

module DataPorter
  class ImportChannel < ActionCable::Channel::Base
    def subscribed
      prefix = DataPorter.configuration.cable_channel_prefix
      stream_from "#{prefix}/imports/#{params[:id]}"
    end
  end
end
