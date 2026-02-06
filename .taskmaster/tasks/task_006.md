# Task ID: 6

**Title:** Implement Registry and auto-discovery

**Status:** pending

**Dependencies:** 5

**Priority:** high

**Description:** Create DataPorter::Registry singleton with class methods: register, find, available, refresh!. Targets auto-register on inheritance using Target.descendants.

**Details:**

Create lib/data_porter/registry.rb. The Registry stores targets in a Hash keyed by parameterized label. register(key, klass) adds to the hash. find(key) looks up or raises DataPorter::TargetNotFound. available returns array of {key:, label:, icon:} hashes. refresh! clears and re-registers all Target descendants that have a _label set. Define DataPorter::TargetNotFound error class.

**Test Strategy:**

Test register and find. Test TargetNotFound error. Test available returns correct format. Test refresh! discovers target subclasses.
