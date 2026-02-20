# frozen_string_literal: true

RSpec.describe DataPorter::WebhookJob do
  let(:url) { "https://hooks.example.com/callback" }
  let(:payload_json) { { event: "import.completed", import: { id: 1 } }.to_json }
  let(:headers) { {} }
  let(:http) { instance_double(Net::HTTP) }
  let(:response) { instance_double(Net::HTTPSuccess, code: "200") }

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response)
  end

  describe "#perform" do
    it "sends a POST request to the webhook url" do
      described_class.new.perform(url, payload_json, headers)

      expect(http).to have_received(:request).once
    end

    it "configures SSL for https urls" do
      described_class.new.perform(url, payload_json, headers)

      expect(http).to have_received(:use_ssl=).with(true)
    end

    it "sets 10 second timeouts" do
      described_class.new.perform(url, payload_json, headers)

      expect(http).to have_received(:open_timeout=).with(10)
      expect(http).to have_received(:read_timeout=).with(10)
    end

    it "sends JSON content type header" do
      described_class.new.perform(url, payload_json, headers)

      expect(http).to have_received(:request) do |req|
        expect(req["Content-Type"]).to eq("application/json")
      end
    end

    it "sends the payload as body" do
      described_class.new.perform(url, payload_json, headers)

      expect(http).to have_received(:request) do |req|
        expect(req.body).to eq(payload_json)
      end
    end

    it "includes custom headers" do
      described_class.new.perform(url, payload_json, { "X-Team" => "ops" })

      expect(http).to have_received(:request) do |req|
        expect(req["X-Team"]).to eq("ops")
      end
    end
  end

  describe "HMAC signing" do
    it "adds signature header when webhook_secret is configured" do
      original = DataPorter.configuration.webhook_secret
      DataPorter.configuration.webhook_secret = "test-secret"

      described_class.new.perform(url, payload_json, headers)

      expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", "test-secret", payload_json)}"
      expect(http).to have_received(:request) do |req|
        expect(req["X-DataPorter-Signature"]).to eq(expected)
      end
    ensure
      DataPorter.configuration.webhook_secret = original
    end

    it "does not add signature header when no secret configured" do
      original = DataPorter.configuration.webhook_secret
      DataPorter.configuration.webhook_secret = nil

      described_class.new.perform(url, payload_json, headers)

      expect(http).to have_received(:request) do |req|
        expect(req["X-DataPorter-Signature"]).to be_nil
      end
    ensure
      DataPorter.configuration.webhook_secret = original
    end
  end

  describe "error handling" do
    it "does not raise on network errors" do
      allow(http).to receive(:request).and_raise(Errno::ECONNREFUSED)

      expect { described_class.new.perform(url, payload_json, headers) }
        .not_to raise_error
    end

    it "does not raise on timeout" do
      allow(http).to receive(:request).and_raise(Net::ReadTimeout)

      expect { described_class.new.perform(url, payload_json, headers) }
        .not_to raise_error
    end
  end
end
