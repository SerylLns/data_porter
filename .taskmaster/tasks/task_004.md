# Task ID: 4

**Title:** Implement TypeValidator

**Status:** pending

**Dependencies:** 1

**Priority:** high

**Description:** Create DataPorter::TypeValidator module with .valid?(value, type, options) class method supporting types: :string, :integer, :decimal, :date, :datetime, :email, :phone, :url, :boolean.

**Details:**

Create lib/data_porter/type_validator.rb. Implement validation for each type: string (always valid if present), integer (Integer(value) rescue false), decimal (Float(value) rescue false), date (Date.parse or strptime with format option), datetime (DateTime.parse), email (regex validation), phone (regex for common formats), url (URI.parse with scheme check), boolean (true/false/'true'/'false'/0/1).

**Test Strategy:**

Test each type with valid and invalid values. Test date with custom format option. Test edge cases (nil, empty string, weird types).
