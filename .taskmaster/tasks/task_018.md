# Task ID: 18

**Title:** Implement JSON source

**Status:** pending

**Dependencies:** 8

**Priority:** medium

**Description:** Create DataPorter::Sources::Json for JSON file upload and raw JSON text input. Supports configurable json_root for nested data extraction.

**Details:**

Create lib/data_porter/sources/json.rb extending Base. fetch method: reads from attached file (download) or from config['raw_json']. Parses JSON, extracts records from json_root path (dot-separated) or root array. Transforms keys to parameterized symbols. Add _json_root DSL to Target class.

**Test Strategy:**

Test parsing from file attachment. Test parsing from raw_json config. Test json_root extraction. Test key transformation.
