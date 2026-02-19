# frozen_string_literal: true

module DataPorter
  class DataImport < ActiveRecord::Base
    self.table_name = "data_porter_imports"

    has_one_attached :file

    belongs_to :user, polymorphic: true, optional: true

    enum :status, {
      pending: 0,
      parsing: 1,
      previewing: 2,
      importing: 3,
      completed: 4,
      failed: 5,
      dry_running: 6,
      extracting_headers: 7,
      mapping: 8
    }

    attribute :records, StoreModels::ImportRecord.to_array_type, default: -> { [] }
    attribute :report, StoreModels::Report.to_type, default: -> { StoreModels::Report.new }

    attribute :config, :json, default: -> { {} }

    scope :purgeable, lambda {
      where(status: %i[completed failed])
        .where(created_at: ...DataPorter.configuration.purge_after.ago)
    }

    validates :target_key, presence: true
    validates :source_type, presence: true, inclusion: { in: %w[csv json api xlsx] }

    def target_class
      Registry.find(target_key)
    end

    def source_class
      Sources.resolve(source_type)
    end

    def previewable?
      previewing? && records.any?
    end

    def importable_records
      records.select(&:importable?)
    end

    def records_summary
      records.group_by(&:status).transform_values(&:count)
    end

    def reset_to_mapping!
      update!(
        status: :mapping,
        records: [],
        report: StoreModels::Report.new,
        config: (config || {}).except("progress")
      )
    end

    def file_based?
      %w[csv xlsx].include?(source_type)
    end
  end
end
