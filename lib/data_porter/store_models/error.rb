# frozen_string_literal: true

require "store_model"

module DataPorter
  module StoreModels
    class Error
      include StoreModel::Model

      attribute :message, :string
    end
  end
end
