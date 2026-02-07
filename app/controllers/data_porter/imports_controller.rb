# frozen_string_literal: true

module DataPorter
  class ImportsController < DataPorter.configuration.parent_controller.constantize
    before_action :set_import, only: %i[show parse confirm cancel dry_run update_mapping]

    def index
      @imports = DataPorter::DataImport.order(created_at: :desc)
      @targets = DataPorter::Registry.available
    end

    def new
      @import = DataPorter::DataImport.new
      @targets = DataPorter::Registry.available
    end

    def create
      @import = DataPorter::DataImport.new(import_params)
      @import.user = current_user if respond_to?(:current_user, true)
      @import.status = :pending

      if @import.save
        enqueue_after_create
        redirect_to import_path(@import)
      else
        @targets = DataPorter::Registry.available
        render :new
      end
    end

    def show
      @target = @import.target_class
      @records = @import.records
      @grouped = @records.group_by(&:status)
      load_mapping_data if @import.mapping?
    end

    def parse
      @import.update!(status: :pending)
      DataPorter::ParseJob.perform_later(@import.id)
      redirect_to import_path(@import)
    end

    def update_mapping
      save_column_mapping
      save_template_if_requested
      DataPorter::ParseJob.perform_later(@import.id)
      redirect_to import_path(@import)
    end

    def confirm
      DataPorter::ImportJob.perform_later(@import.id)
      redirect_to import_path(@import)
    end

    def cancel
      @import.update!(status: :failed)
      redirect_to imports_path
    end

    def dry_run
      DataPorter::DryRunJob.perform_later(@import.id)
      redirect_to import_path(@import)
    end

    private

    def set_import
      @import = DataPorter::DataImport.find(params[:id])
    end

    def import_params
      params.require(:data_import).permit(:target_key, :source_type, :file, config: {})
    end

    def enqueue_after_create
      if @import.file_based?
        DataPorter::ExtractHeadersJob.perform_later(@import.id)
      else
        DataPorter::ParseJob.perform_later(@import.id)
      end
    end

    def load_mapping_data
      @file_headers = @import.config["file_headers"] || []
      @target_columns = target_field_options
      @default_mapping = build_default_mapping
      @templates = load_templates
    end

    def target_field_options
      target = @import.target_class
      columns = target._columns || []
      columns.map { |c| [c.label, c.name.to_s] }
    end

    def build_default_mapping
      target = @import.target_class
      mappings = target._csv_mappings || {}
      mappings.transform_values(&:to_s)
    end

    def load_templates
      return [] unless defined?(DataPorter::MappingTemplate)

      DataPorter::MappingTemplate.for_target(@import.target_key)
    end

    def save_column_mapping
      mapping = params.require(:column_mapping).permit!.to_h
      config = @import.config || {}
      config["column_mapping"] = mapping
      @import.update!(config: config, status: :pending)
    end

    def save_template_if_requested
      return unless params[:save_template] == "1"
      return unless defined?(DataPorter::MappingTemplate)

      mapping = params.require(:column_mapping).permit!.to_h
      DataPorter::MappingTemplate.find_or_initialize_by(
        target_key: @import.target_key,
        name: params[:template_name].presence || "Default"
      ).update!(mapping: mapping)
    end
  end
end
