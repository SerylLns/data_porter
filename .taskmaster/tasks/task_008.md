# Task ID: 8

**Title:** Implement Source base class and CSV source

**Status:** pending

**Dependencies:** 5, 7

**Priority:** high

**Description:** Create DataPorter::Sources::Base abstract class and DataPorter::Sources::Csv implementation. Include DataPorter::Sources.resolve class method for source type lookup.

**Details:**

Create lib/data_porter/sources/base.rb with initialize(data_import), abstract fetch method, and private apply_csv_mapping helper (uses target's _csv_mappings or falls back to parameterize auto-mapping). Create lib/data_porter/sources/csv.rb extending Base: fetch reads the attached file via ActiveStorage, parses with Ruby CSV (headers: true + target's csv_options), applies csv_mapping to each row. Create lib/data_porter/sources.rb with resolve(type) method that maps 'csv' -> Csv, 'json' -> Json, 'api' -> Api.

**Test Strategy:**

Test CSV parsing with headers. Test csv_mapping application (explicit and auto). Test resolve method returns correct class. Test with various CSV formats (different separators, encodings).
