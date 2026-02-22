# frozen_string_literal: true

module DataPorter
  class ImportsController < DataPorter.configuration.parent_controller.constantize
    include Concerns::ImportValidation
    include Concerns::MappingManagement
    include Concerns::RecordPagination
    include Concerns::ScopeManagement

    layout "data_porter/application"

    before_action :set_import, only: %i[show parse confirm cancel dry_run update_mapping
                                        update_record status export_rejects destroy
                                        back_to_mapping resume]
    before_action :ensure_previewing, only: :update_record
    before_action :load_targets, only: %i[index new create]

    def index
      @imports = scoped_imports.order(created_at: :desc)
    end

    def new
      @import = DataPorter::DataImport.new
    end

    def create
      build_import

      if all_validations_pass? && @import.save
        enqueue_after_create
        redirect_to import_path(@import)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show
      @target = @import.target_class
      @records = @import.records
      @grouped = @records.group_by(&:status)
      paginate_records
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
      @import.update!(status: :pending)
      DataPorter::ImportJob.perform_later(@import.id)
      redirect_to import_path(@import)
    end

    def cancel
      @import.update!(status: :failed)
      redirect_to imports_path
    end

    def back_to_mapping
      @import.reset_to_mapping!
      redirect_to import_path(@import)
    end

    def resume
      @import.update!(status: :pending)
      DataPorter::ImportJob.perform_later(@import.id)
      redirect_to import_path(@import)
    end

    def dry_run
      @import.update!(status: :pending)
      DataPorter::DryRunJob.perform_later(@import.id)
      redirect_to import_path(@import)
    end

    def update_record
      updater = RecordUpdater.new(@import)
      result = updater.call(
        line_number: params[:line_number].to_i,
        column: params[:column],
        value: params[:value]
      )
      render json: result
    end

    def status
      progress = @import.config["progress"] || {}
      render json: { status: @import.status, progress: progress }
    end

    def export_rejects
      columns = @import.target_class._columns || []
      csv = RejectsCsvBuilder.new(columns, @import.records).generate
      send_data csv, filename: "rejects_import_#{@import.id}.csv", type: "text/csv"
    end

    def destroy
      @import.file.purge if @import.file.attached?
      @import.destroy!
      redirect_to imports_path
    end

    private

    def set_import
      @import = scoped_imports.find(params[:id])
    end

    def ensure_previewing
      return if @import.previewing?

      render json: { error: "Import is not in previewing state" }, status: :unprocessable_entity
    end

    def scoped_imports
      owner = resolve_owner
      return DataPorter::DataImport.all unless owner

      DataPorter::DataImport.where(user: owner)
    end

    def load_targets
      @targets = DataPorter::Registry.available
    end

    def build_import
      @import = DataPorter::DataImport.new(import_params)
      @import.user = resolve_owner
      @import.status = :pending
    end

    def all_validations_pass?
      [
        valid_source_for_target?,
        valid_file_presence?,
        valid_file_size?,
        valid_file_content_type?,
        valid_import_params?
      ].all?
    end

    def import_params
      permitted = params.require(:data_import).permit(:target_key, :source_type, :file, config: {})
      merge_import_params(permitted)
    end

    def merge_import_params(permitted)
      nested = params.dig(:data_import, :config, :import_params)
      return permitted unless nested

      config = permitted[:config]&.to_unsafe_h || {}
      config["import_params"] = nested.permit(*allowed_param_keys).to_h
      permitted.merge(config: config)
    end

    def allowed_param_keys
      target_key = params.dig(:data_import, :target_key)
      return [] unless target_key

      target = DataPorter::Registry.find(target_key)
      (target._params || []).map { |p| p.name.to_s }
    end

    def enqueue_after_create
      if @import.file_based?
        DataPorter::ExtractHeadersJob.perform_later(@import.id)
      else
        DataPorter::ParseJob.perform_later(@import.id)
      end
    end
  end
end
