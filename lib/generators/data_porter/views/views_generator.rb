# frozen_string_literal: true

require "rails/generators"

module DataPorter
  module Generators
    class ViewsGenerator < Rails::Generators::Base
      SCOPES = %w[imports mapping_templates layout].freeze

      source_root DataPorter::Engine.root.join("app/views")

      argument :scope, type: :string, required: false, default: nil

      def copy_views
        validate_scope! if scope
        scopes = scope ? [scope] : SCOPES

        scopes.each { |s| send(:"copy_#{s}") }
      end

      private

      def copy_imports
        directory "data_porter/imports", "app/views/data_porter/imports"
      end

      def copy_mapping_templates
        directory "data_porter/mapping_templates", "app/views/data_porter/mapping_templates"
      end

      def copy_layout
        layout_src = DataPorter::Engine.root.join("app/views/layouts/data_porter/application.html.erb")
        copy_file layout_src, "app/views/layouts/data_porter/application.html.erb"
      end

      def validate_scope!
        return if SCOPES.include?(scope)

        raise Thor::Error, "Unknown scope '#{scope}'. Valid scopes: #{SCOPES.join(", ")}"
      end
    end
  end
end
