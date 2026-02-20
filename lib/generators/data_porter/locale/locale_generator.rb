# frozen_string_literal: true

require "rails/generators"

module DataPorter
  module Generators
    class LocaleGenerator < Rails::Generators::Base
      argument :locale, type: :string, default: "en"

      def copy_locale_file
        source = engine_locale_path
        destination = "config/locales/data_porter.#{locale}.yml"

        if File.exist?(source)
          copy_file(source, destination)
          gsub_file(destination, /^#{source_locale}:/, "#{locale}:")
        else
          create_from_english(destination)
        end
      end

      private

      def engine_locale_path
        File.expand_path("../../../../config/locales/#{locale}.yml", __dir__)
      end

      def english_locale_path
        File.expand_path("../../../../config/locales/en.yml", __dir__)
      end

      def source_locale
        File.exist?(engine_locale_path) ? locale : "en"
      end

      def create_from_english(destination)
        copy_file(english_locale_path, destination)
        gsub_file(destination, /^en:/, "#{locale}:")
      end
    end
  end
end
