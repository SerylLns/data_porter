# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
ENV["DATABASE_URL"] = "sqlite3::memory:"

require "rails"
require "active_record"
require "active_job"
require "action_controller"
require "action_cable"
require "active_storage/engine"

module TestApp
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.active_storage.service = :test
    config.active_storage.service_configurations = {
      test: { service: "Disk", root: Dir.tmpdir }
    }
    config.active_job.queue_adapter = :test
    config.secret_key_base = "test_secret"
    config.root = File.expand_path("..", __dir__)
  end
end

require "data_porter"

Rails.application.initialize!

Rails.application.routes.draw do
  mount DataPorter::Engine, at: "/data_porter"
end

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :data_porter_imports, force: true do |t|
    t.string  :target_key,  null: false, default: ""
    t.string  :source_type, null: false, default: "csv"
    t.integer :status,      null: false, default: 0
    t.text    :records
    t.text    :report
    t.text    :config

    t.string  :user_type
    t.integer :user_id

    t.timestamps
  end

  create_table :data_porter_mapping_templates, force: true do |t|
    t.string :target_key, null: false
    t.string :name,       null: false
    t.text   :mapping,    null: false, default: "{}"
    t.timestamps
  end

  add_index :data_porter_mapping_templates, :target_key
  add_index :data_porter_mapping_templates, %i[target_key name], unique: true

  create_table :active_storage_blobs, force: true do |t|
    t.string   :key,          null: false
    t.string   :filename,     null: false
    t.string   :content_type
    t.text     :metadata
    t.string   :service_name, null: false
    t.bigint   :byte_size,    null: false
    t.string   :checksum

    t.datetime :created_at, null: false

    t.index [:key], unique: true
  end

  create_table :active_storage_attachments, force: true do |t|
    t.string     :name,     null: false
    t.references :record,   null: false, polymorphic: true, index: false
    t.references :blob,     null: false

    t.datetime :created_at, null: false

    t.index %i[record_type record_id name blob_id],
            name: "index_active_storage_attachments_uniqueness",
            unique: true
  end

  create_table :active_storage_variant_records, force: true do |t|
    t.belongs_to :blob, null: false, index: false
    t.string :variation_digest, null: false

    t.index %i[blob_id variation_digest],
            name: "index_active_storage_variant_records_uniqueness",
            unique: true
  end
end

class User < ActiveRecord::Base; end unless defined?(User)

%w[models jobs].each do |dir|
  $LOAD_PATH.unshift File.expand_path("../app/#{dir}", __dir__)
end
require "data_porter/data_import"
require "data_porter/parse_job"
require "data_porter/import_job"
require "data_porter/dry_run_job"
require "data_porter/extract_headers_job"
require "data_porter/mapping_template"

class ApplicationController < ActionController::Base; end unless defined?(ApplicationController)

$LOAD_PATH.unshift File.expand_path("../app/controllers", __dir__)
require "data_porter/imports_controller"
require "data_porter/mapping_templates_controller"

$LOAD_PATH.unshift File.expand_path("../app/channels", __dir__)
require "data_porter/import_channel"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
