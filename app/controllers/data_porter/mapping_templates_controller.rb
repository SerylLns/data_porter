# frozen_string_literal: true

module DataPorter
  class MappingTemplatesController < DataPorter.configuration.parent_controller.constantize
    layout "data_porter/application"

    before_action :set_template, only: %i[edit update destroy]

    def index
      @templates = MappingTemplate.order(:target_key, :name)
      @grouped = @templates.group_by(&:target_key)
    end

    def new
      @template = MappingTemplate.new
      load_form_data
    end

    def create
      @template = MappingTemplate.new(template_params)

      if @template.save
        redirect_to mapping_templates_path
      else
        load_form_data
        render :new
      end
    end

    def edit
      load_form_data
    end

    def update
      if @template.update(template_params)
        redirect_to mapping_templates_path
      else
        load_form_data
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
      permitted = params.require(:mapping_template).permit(
        :target_key, :name, mapping: {}, mapping_keys: [], mapping_values: []
      )
      build_mapping_from_arrays(permitted)
    end

    def build_mapping_from_arrays(raw)
      keys = raw.delete(:mapping_keys)
      values = raw.delete(:mapping_values)
      return raw unless keys && values

      mapping = keys.zip(values).reject { |k, _| k.blank? }.to_h
      raw.merge(mapping: mapping)
    end

    def load_form_data
      @targets = Registry.available
      @target_columns_map = build_target_columns_map
    end

    def build_target_columns_map
      columns = {}
      @targets.each do |t|
        target = Registry.find(t[:key])
        cols = target._columns || []
        columns[t[:key].to_s] = cols.map { |c| [c.label, c.name.to_s] }
      end
      columns
    end
  end
end
