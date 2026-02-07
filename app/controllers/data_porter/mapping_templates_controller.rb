# frozen_string_literal: true

module DataPorter
  class MappingTemplatesController < DataPorter.configuration.parent_controller.constantize
    before_action :set_template, only: %i[edit update destroy]

    def index
      @templates = MappingTemplate.order(:target_key, :name)
      @grouped = @templates.group_by(&:target_key)
    end

    def new
      @template = MappingTemplate.new
      @targets = Registry.available
    end

    def create
      @template = MappingTemplate.new(template_params)

      if @template.save
        redirect_to mapping_templates_path
      else
        @targets = Registry.available
        render :new
      end
    end

    def edit
      @targets = Registry.available
    end

    def update
      if @template.update(template_params)
        redirect_to mapping_templates_path
      else
        @targets = Registry.available
        render :edit
      end
    end

    def destroy
      @template.destroy
      redirect_to mapping_templates_path
    end

    private

    def set_template
      @template = MappingTemplate.find(params[:id])
    end

    def template_params
      params.require(:mapping_template).permit(:target_key, :name, mapping: {})
    end
  end
end
