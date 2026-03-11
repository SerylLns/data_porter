# frozen_string_literal: true

require "net/http"

RSpec.describe DataPorter::Sources::Api do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Stays"
      model_name "Stay"

      api_config do
        endpoint "https://api.example.com/stays"
        headers({ "Authorization" => "Bearer test123" })
        response_root :stays
      end

      columns do
        column :name, type: :string
      end
    end
  end

  let(:import) do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:stays, target_class)
    DataPorter::DataImport.create!(
      target_key: "stays",
      source_type: "api",
      user_type: "User",
      user_id: 1
    )
  end

  after { DataPorter::Registry.clear }

  describe "#fetch with static endpoint" do
    it "fetches and parses records from response_root" do
      response_body = '{"stays": [{"name": "Beach House"}, {"name": "Mountain Cabin"}]}'
      stub_http_get(response_body)

      source = described_class.new(import)
      records = source.fetch

      expect(records.size).to eq(2)
      expect(records.first["name"]).to eq("Beach House")
    end
  end

  describe "#fetch with lambda endpoint" do
    let(:target_with_lambda) do
      Class.new(DataPorter::Target) do
        label "Dynamic"
        model_name "Dynamic"

        api_config do
          endpoint ->(params) { "https://api.example.com/items?id=#{params[:item_id]}" }
          headers({})
        end

        columns do
          column :title, type: :string
        end
      end
    end

    let(:import_with_lambda) do
      DataPorter::Registry.register(:dynamic, target_with_lambda)
      DataPorter::DataImport.create!(
        target_key: "dynamic",
        source_type: "api",
        config: { "item_id" => "42" },
        user_type: "User",
        user_id: 1
      )
    end

    it "resolves the endpoint lambda with params" do
      response_body = '[{"title": "Item 42"}]'
      stub_http_get(response_body)

      source = described_class.new(import_with_lambda)
      records = source.fetch

      expect(records.first["title"]).to eq("Item 42")
    end
  end

  describe "#fetch with lambda headers" do
    let(:target_with_lambda_headers) do
      Class.new(DataPorter::Target) do
        label "Auth"
        model_name "Auth"

        api_config do
          endpoint "https://api.example.com/data"
          headers(-> { { "Authorization" => "Bearer dynamic_token" } })
        end

        columns do
          column :value, type: :string
        end
      end
    end

    let(:import_with_lambda_headers) do
      DataPorter::Registry.register(:auth, target_with_lambda_headers)
      DataPorter::DataImport.create!(
        target_key: "auth",
        source_type: "api",
        user_type: "User",
        user_id: 1
      )
    end

    it "resolves lambda headers" do
      response_body = '[{"value": "secret"}]'
      stub_http_get(response_body)

      source = described_class.new(import_with_lambda_headers)
      records = source.fetch

      expect(records.first["value"]).to eq("secret")
    end
  end

  describe "#fetch without response_root" do
    let(:target_no_root) do
      Class.new(DataPorter::Target) do
        label "Flat"
        model_name "Flat"

        api_config do
          endpoint "https://api.example.com/flat"
          headers({})
        end

        columns do
          column :name, type: :string
        end
      end
    end

    let(:import_no_root) do
      DataPorter::Registry.register(:flat, target_no_root)
      DataPorter::DataImport.create!(
        target_key: "flat",
        source_type: "api",
        user_type: "User",
        user_id: 1
      )
    end

    it "uses the root array directly" do
      response_body = '[{"name": "Direct"}]'
      stub_http_get(response_body)

      source = described_class.new(import_no_root)
      records = source.fetch

      expect(records.first["name"]).to eq("Direct")
    end
  end

  describe "#fetch transforms keys" do
    it "parameterizes keys to strings" do
      response_body = '{"stays": [{"Full Name": "Alice Smith"}]}'
      stub_http_get(response_body)

      source = described_class.new(import)
      records = source.fetch

      expect(records.first["full_name"]).to eq("Alice Smith")
    end
  end

  private

  def stub_http_get(body)
    response = instance_double(Net::HTTPResponse, body: body)
    allow(Net::HTTP).to receive(:start).and_return(response)
  end
end
