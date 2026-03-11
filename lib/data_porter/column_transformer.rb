# frozen_string_literal: true

module DataPorter
  module ColumnTransformer
    BUILT_IN = {
      strip: :strip.to_proc,
      downcase: :downcase.to_proc,
      upcase: :upcase.to_proc,
      titleize: :titleize.to_proc,
      normalize_phone: ->(value) { value.gsub(/[\s\-().]+/, "") },
      parse_date: ->(value) { Date.parse(value).iso8601 rescue value }, # rubocop:disable Style/RescueModifier
      parse_boolean: ->(value) { %w[true 1 yes oui].include?(value.downcase) ? "true" : "false" },
      parse_integer: ->(value) { Float(value, exception: false) ? value.to_f.to_i.to_s : value },
      parse_decimal: ->(value) { Float(value, exception: false)&.to_s || value }
    }.freeze

    def self.apply(value, transformer_name)
      return value if value.nil?

      transformer = BUILT_IN[transformer_name] || custom_transformers[transformer_name]
      raise Error, "Unknown transformer: #{transformer_name}" unless transformer

      transformer.call(value.to_s)
    end

    def self.register(name, &block)
      custom_transformers[name.to_sym] = block
    end

    def self.apply_all(record, columns)
      columns.each do |col|
        next if col.transform.empty?

        key = resolve_key(record.data, col.name)
        next unless key

        col.transform.each do |t|
          record.data[key] = apply(record.data[key], t)
        end
      end
    end

    def self.resolve_key(data, name)
      key = name.to_s
      key if data.key?(key)
    end

    def self.custom_transformers
      @custom_transformers ||= {}
    end

    private_class_method :custom_transformers, :resolve_key
  end
end
