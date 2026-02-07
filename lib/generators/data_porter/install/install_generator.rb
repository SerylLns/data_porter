# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module DataPorter
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def copy_migration
        migration_template(
          "create_data_porter_imports.rb.erb",
          "db/migrate/create_data_porter_imports.rb"
        )
        migration_template(
          "create_data_porter_mapping_templates.rb.erb",
          "db/migrate/create_data_porter_mapping_templates.rb"
        )
      end

      def copy_initializer
        template("initializer.rb", "config/initializers/data_porter.rb")
      end

      def create_importers_directory
        empty_directory("app/importers")
      end

      def mount_engine
        route 'mount DataPorter::Engine, at: "/imports"'
      end
    end
  end
end
