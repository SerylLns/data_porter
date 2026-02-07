# frozen_string_literal: true

namespace :data_porter do
  desc "Purge old completed/failed imports (default: 60 days, configure via purge_after)"
  task purge: :environment do
    count = DataPorter::DataImport.purgeable.destroy_all.count
    puts "DataPorter: purged #{count} old import(s)"
  end
end
