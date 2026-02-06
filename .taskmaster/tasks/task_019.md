# Task ID: 19

**Title:** Implement API source

**Status:** pending

**Dependencies:** 8

**Priority:** medium

**Description:** Create DataPorter::Sources::Api for HTTP endpoint fetching. Uses target's api_config (endpoint, headers, response_root) with params injection.

**Details:**

Create lib/data_porter/sources/api.rb extending Base. fetch method: resolves endpoint URL (lambda or string) with params from data_import.config, resolves headers (lambda or hash), makes HTTP GET with Net::HTTP, parses JSON response, extracts records from response_root, transforms keys. Add api_config DSL block to Target with endpoint, headers, response_root setters.

**Test Strategy:**

Test with mocked HTTP responses. Test endpoint lambda resolution. Test header resolution. Test response_root extraction. Test error handling for failed requests.
