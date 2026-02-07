# frozen_string_literal: true

require "rake"

RSpec.describe "data_porter:purge" do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "PurgeTest"
      model_name "PurgeTest"
    end
  end

  before(:all) do
    Rails.application.load_tasks
  end

  before do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:purge_test, target_class)
    Rake::Task["data_porter:purge"].reenable
  end

  after { DataPorter::Registry.clear }

  it "destroys purgeable imports" do
    old = DataPorter::DataImport.create!(
      target_key: "purge_test", source_type: "csv", status: :completed,
      created_at: 61.days.ago
    )
    recent = DataPorter::DataImport.create!(
      target_key: "purge_test", source_type: "csv", status: :completed,
      created_at: 1.day.ago
    )

    Rake::Task["data_porter:purge"].invoke

    expect(DataPorter::DataImport.exists?(old.id)).to be false
    expect(DataPorter::DataImport.exists?(recent.id)).to be true
  end
end
