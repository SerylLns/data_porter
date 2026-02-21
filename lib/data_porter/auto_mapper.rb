# frozen_string_literal: true

module DataPorter
  class AutoMapper
    SYNONYMS = {
      email: %w[email e_mail email_address e_mail_address courriel mail],
      first_name: %w[first_name firstname fname first prenom],
      last_name: %w[last_name lastname lname last nom],
      name: %w[name full_name fullname nom_complet],
      phone_number: %w[phone_number phone tel telephone mobile cell],
      address: %w[address addr street adresse],
      city: %w[city ville town],
      zip_code: %w[zip_code zip postal_code postcode code_postal],
      country: %w[country pays nation],
      company: %w[company company_name organization organisation entreprise societe],
      title: %w[title job_title position titre poste],
      description: %w[description desc notes],
      quantity: %w[quantity qty amount],
      price: %w[price unit_price prix montant],
      date: %w[date created_at updated_at],
      status: %w[status state statut etat],
      id: %w[id identifier external_id ref reference]
    }.freeze

    def initialize(headers, target_columns, custom_synonyms: {})
      @headers = headers
      @target_columns = target_columns.map(&:to_s)
      @custom_synonyms = custom_synonyms
    end

    def call
      used = Set.new
      @headers.each_with_object({}) do |header, mapping|
        match = find_match(header, used)
        used.add(match) if match
        mapping[header] = match || ""
      end
    end

    private

    def find_match(header, used)
      normalized = normalize(header)
      return nil if normalized.empty?

      exact_match(normalized, used) || synonym_match(normalized, used)
    end

    def exact_match(normalized, used)
      @target_columns.find { |col| col == normalized && !used.include?(col) }
    end

    def synonym_match(normalized, used)
      lookup_table[normalized]&.find { |col| !used.include?(col) }
    end

    def lookup_table
      @lookup_table ||= build_lookup_table
    end

    def build_lookup_table
      table = Hash.new { |h, k| h[k] = [] }
      merged_synonyms.each do |column, synonyms|
        col_name = column.to_s
        next unless @target_columns.include?(col_name)

        synonyms.each { |syn| table[syn] << col_name }
      end
      table
    end

    def merged_synonyms
      result = SYNONYMS.transform_values(&:dup)
      @custom_synonyms.each do |column, syns|
        key = column.to_sym
        result[key] = (result.fetch(key, []) + syns.map { |s| normalize(s) }).uniq
      end
      result
    end

    def normalize(header)
      return "" if header.nil?

      header.to_s.strip.downcase.gsub(/[\s-]+/, "_").gsub(/[^a-z0-9_]/, "")
    end
  end
end
