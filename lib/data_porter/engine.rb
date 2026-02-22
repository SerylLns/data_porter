# frozen_string_literal: true

module DataPorter
  class Engine < ::Rails::Engine
    isolate_namespace DataPorter

    initializer "data_porter.i18n" do
      config.i18n.load_path += Dir[root.join("config/locales/**/*.yml")]
    end

    initializer "data_porter.assets.precompile" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[
          data_porter/application.css
          data_porter/turbo.min.js
          data_porter/stimulus.min.js
          data_porter/mapping_controller.js
          data_porter/template_form_controller.js
          data_porter/progress_controller.js
          data_porter/import_form_controller.js
          data_porter/theme_controller.js
          data_porter/inline_edit_controller.js
        ]
      end
    end

    config.to_prepare do
      Dir[Rails.root.join("app/importers/*_target.rb")].each { |f| require f }
    end
  end
end
