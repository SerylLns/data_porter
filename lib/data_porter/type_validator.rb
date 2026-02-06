# frozen_string_literal: true

require "uri"
require "date"

module DataPorter
  module TypeValidator
    VALIDATORS = {
      string: ->(_value, _opts) { true },
      integer: ->(value, _opts) { Integer(value, exception: false) },
      decimal: ->(value, _opts) { Float(value, exception: false) },
      date: ->(value, opts) { parse_date(value, opts) },
      datetime: ->(value, _opts) { DateTime.parse(value) rescue false }, # rubocop:disable Style/RescueModifier
      email: ->(value, _opts) { value.match?(/\A[^@\s]+@[^@\s]+\z/) },
      phone: ->(value, _opts) { value.match?(/\A[+\d][\d\s\-().]{6,}\z/) },
      url: ->(value, _opts) { valid_url?(value) },
      boolean: ->(value, _opts) { %w[true false 1 0].include?(value.to_s.downcase) }
    }.freeze

    def self.valid?(value, type, options = {})
      validator = VALIDATORS[type.to_sym]
      return true unless validator

      !!validator.call(value.to_s, options)
    end

    def self.parse_date(value, opts)
      if opts[:format]
        Date.strptime(value.to_s, opts[:format])
      else
        Date.parse(value.to_s)
      end
    rescue ArgumentError
      false
    end

    def self.valid_url?(value)
      uri = URI.parse(value.to_s)
      uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      false
    end

    private_class_method :parse_date, :valid_url?
  end
end
