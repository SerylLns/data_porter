# frozen_string_literal: true

require "rails/generators"

module DataPorter
  module Generators
    class LocaleGenerator < Rails::Generators::Base
      source_root File.expand_path("../../../../config/locales", __dir__)

      argument :locale, type: :string, default: "en"

      def copy_locale_file
        source = source_file
        destination = "config/locales/data_porter.#{locale}.yml"

        copy_file(source, destination)
        gsub_file(destination, /^#{source_locale}:/, "#{locale}:") unless locale == source_locale
      end

      def show_instructions
        say ""
        say "DataPorter locale file created: config/locales/data_porter.#{locale}.yml", :green
        say ""
        say "Next steps:"
        say "  1. Translate the values in the generated file"
        say "  2. Set your default locale in config/application.rb:"
        say "       config.i18n.default_locale = :#{locale}"
        say ""
      end

      private

      def source_file
        File.exist?(File.join(self.class.source_root, "#{locale}.yml")) ? "#{locale}.yml" : "en.yml"
      end

      def source_locale
        source_file.delete_suffix(".yml")
      end
    end
  end
end
