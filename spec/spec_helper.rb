# frozen_string_literal: true

require "rails"
require "active_record"
require "data_porter"

$LOAD_PATH.unshift File.expand_path("../app/models", __dir__)
require "data_porter/data_import"

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

ActiveRecord::Schema.define do
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
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
