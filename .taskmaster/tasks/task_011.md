# Task ID: 11

**Title:** Implement ActionCable Broadcaster and ImportChannel

**Status:** pending

**Dependencies:** 1

**Priority:** medium

**Description:** Create DataPorter::Broadcaster for real-time progress updates and DataPorter::ImportChannel for client subscriptions.

**Details:**

Create lib/data_porter/broadcaster.rb: initialize(import_id) builds channel name from cable_channel_prefix config. progress(current, total) broadcasts percentage. success() broadcasts success status. failure(message) broadcasts failure with error. Create app/channels/data_porter/import_channel.rb: subscribes to the import-specific channel stream.

**Test Strategy:**

Test broadcaster formats messages correctly. Test channel subscribes to correct stream. Test progress percentage calculation.
