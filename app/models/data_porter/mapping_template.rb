# frozen_string_literal: true

module DataPorter
  class MappingTemplate < ActiveRecord::Base
    self.table_name = "data_porter_mapping_templates"

    belongs_to :user, polymorphic: true, optional: true

    attribute :mapping, :json, default: -> { {} }

    validates :target_key, presence: true
    validates :name, presence: true, uniqueness: { scope: :target_key }
    validates :mapping, presence: true

    scope :for_target, ->(key) { where(target_key: key) }
  end
end
