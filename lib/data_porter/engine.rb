# frozen_string_literal: true

module DataPorter
  class Engine < ::Rails::Engine
    isolate_namespace DataPorter

    config.to_prepare do
      Dir[Rails.root.join("app/importers/*_target.rb")].each { |f| require f }
    end
  end
end
