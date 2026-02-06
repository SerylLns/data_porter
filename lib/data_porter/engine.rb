# frozen_string_literal: true

module DataPorter
  class Engine < ::Rails::Engine
    isolate_namespace DataPorter

    initializer "data_porter.assets.precompile" do |app|
      app.config.assets.precompile += %w[data_porter/application.css] if app.config.respond_to?(:assets)
    end

    config.to_prepare do
      Dir[Rails.root.join("app/importers/*_target.rb")].each { |f| require f }
    end
  end
end
