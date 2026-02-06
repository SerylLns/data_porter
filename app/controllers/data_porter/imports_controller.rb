# frozen_string_literal: true

module DataPorter
  class ImportsController < DataPorter.configuration.parent_controller.constantize
    before_action :set_import, only: %i[show parse confirm cancel dry_run]

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
        DataPorter::ParseJob.perform_later(@import.id)
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
    end

    def parse
      @import.update!(status: :pending)
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
  end
end
