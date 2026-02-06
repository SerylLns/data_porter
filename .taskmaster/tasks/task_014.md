# Task ID: 14

**Title:** Implement Stimulus progress controller

**Status:** pending

**Dependencies:** 11, 13

**Priority:** medium

**Description:** Create the Stimulus controller for real-time progress updates via ActionCable. Connects to ImportChannel, updates progress bar and auto-reloads on completion.

**Details:**

Create app/javascript/data_porter/progress_controller.js (or app/assets/javascript/). Stimulus controller with targets: bar, text. Values: id (Number). On connect: subscribe to ImportChannel with the import id. On received: if status is 'processing', update bar width and text with percentage. If status is 'success' or 'failure', reload page. On disconnect: unsubscribe.

**Test Strategy:**

Test controller connects to correct channel. Test progress bar updates. Test page reload on completion.
