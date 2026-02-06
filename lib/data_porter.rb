# frozen_string_literal: true

require "rails/engine"
require_relative "data_porter/version"
require_relative "data_porter/engine"

module DataPorter
  class Error < StandardError; end
end
