# Task ID: 16

**Title:** Create target generator

**Status:** pending

**Dependencies:** 5

**Priority:** medium

**Description:** Implement rails generate data_porter:target NAME [columns...] generator that scaffolds a target class in app/importers/.

**Details:**

Create lib/generators/data_porter/target_generator.rb. Arguments: name (required), columns (optional, format: name:type or name:type:required). Generate app/importers/{name}_target.rb with: class inheriting DataPorter::Target, label, model (inferred from name), sources :csv, columns block from arguments, empty persist method. Template in lib/generators/data_porter/templates/target.rb.tt.

**Test Strategy:**

Test generator creates target file with correct class name. Test column parsing (type, required flag). Test generated file is valid Ruby.
