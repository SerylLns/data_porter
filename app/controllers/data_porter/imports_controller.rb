# frozen_string_literal: true

module DataPorter
  class ImportsController < DataPorter.configuration.parent_controller.constantize
    layout "data_porter/application"

    before_action :set_import, only: %i[show parse confirm cancel dry_run update_mapping]
    before_action :load_targets, only: %i[index new create]

    def index
      @imports = DataPorter::DataImport.order(created_at: :desc)
    end

    def new
      @import = DataPorter::DataImport.new
    end

    def create
      build_import

      if valid_file_presence? && @import.save
        enqueue_after_create
        redirect_to import_path(@import)
      else
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

    def load_targets
      @targets = DataPorter::Registry.available
    end

    def build_import
      @import = DataPorter::DataImport.new(import_params)
      @import.user = current_user if respond_to?(:current_user, true)
      @import.status = :pending
    end

    def import_params
      params.require(:data_import).permit(:target_key, :source_type, :file, config: {})
    end

    def valid_file_presence?
      return true unless %w[csv json xlsx].include?(@import.source_type)
      return true if @import.file.attached?

      @import.errors.add(:file, "must be attached for #{@import.source_type.upcase} imports")
      false
    end

    def enqueue_after_create
      if @import.file_based?
        DataPorter::ExtractHeadersJob.perform_later(@import.id)
      else
        DataPorter::ParseJob.perform_later(@import.id)
      end
    end

    def load_mapping_data
      target = @import.target_class
      columns = target._columns || []
      @file_headers = @import.config["file_headers"] || []
      @target_columns = columns.map { |c| [c.label, c.name.to_s, c.required] }
      @default_mapping = (target._csv_mappings || {}).transform_values(&:to_s)
      @templates = load_templates
    end

    def load_templates
      return [] unless defined?(DataPorter::MappingTemplate)

      DataPorter::MappingTemplate.for_target(@import.target_key)
    end

    def save_column_mapping
      mapping = params.require(:column_mapping).permit!.to_h
      merged = (@import.config || {}).merge("column_mapping" => mapping)
      @import.update!(config: merged, status: :pending)
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
