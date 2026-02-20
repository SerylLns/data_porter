# frozen_string_literal: true

RSpec.describe DataPorter::DSL::Webhook do
  describe "defaults" do
    subject(:webhook) { described_class.new(url: "https://example.com/hook") }

    it "stores the url" do
      expect(webhook.url).to eq("https://example.com/hook")
    end

    it "defaults events to all four" do
      expect(webhook.events).to eq(%i[started completed failed parsed])
    end

    it "defaults headers to empty hash" do
      expect(webhook.headers).to eq({})
    end

    it "defaults payload to nil" do
      expect(webhook.payload).to be_nil
    end
  end

  describe "custom values" do
    subject(:webhook) do
      described_class.new(
        url: "https://hooks.slack.com/xxx",
        events: %i[completed failed],
        headers: { "X-Custom" => "value" },
        payload: ->(_, _, data) { data.merge(team: "ops") }
      )
    end

    it "stores filtered events as symbols" do
      expect(webhook.events).to eq(%i[completed failed])
    end

    it "stores custom headers" do
      expect(webhook.headers).to eq("X-Custom" => "value")
    end

    it "stores custom payload lambda" do
      result = webhook.payload.call(nil, nil, { foo: 1 })
      expect(result).to eq(foo: 1, team: "ops")
    end
  end

  describe "event validation" do
    it "accepts valid events" do
      expect { described_class.new(url: "https://x.com", events: %i[started completed]) }
        .not_to raise_error
    end

    it "rejects invalid events" do
      expect { described_class.new(url: "https://x.com", events: [:invalid]) }
        .to raise_error(ArgumentError, /invalid webhook event: invalid/)
    end

    it "symbolizes string events" do
      webhook = described_class.new(url: "https://x.com", events: ["completed"])

      expect(webhook.events).to eq([:completed])
    end
  end

  describe "url validation" do
    it "requires a url" do
      expect { described_class.new(url: nil) }
        .to raise_error(ArgumentError, /url is required/)
    end

    it "rejects blank url" do
      expect { described_class.new(url: "") }
        .to raise_error(ArgumentError, /url is required/)
    end
  end

  describe "Target DSL integration" do
    let(:target_class) do
      Class.new(DataPorter::Target) do
        label "WebhookTest"

        webhooks do
          webhook "https://hooks.slack.com/xxx",
                  events: %i[completed failed],
                  headers: { "X-Team" => "ops" }
          webhook "https://monitoring.internal/ingest",
                  events: [:completed]
        end
      end
    end

    it "registers webhooks on the target class" do
      expect(target_class._webhooks.size).to eq(2)
    end

    it "stores webhook urls" do
      urls = target_class._webhooks.map(&:url)
      expect(urls).to eq(%w[https://hooks.slack.com/xxx https://monitoring.internal/ingest])
    end

    it "stores webhook events" do
      expect(target_class._webhooks.first.events).to eq(%i[completed failed])
    end

    it "returns nil when no webhooks declared" do
      empty_target = Class.new(DataPorter::Target) { label "NoHooks" }
      expect(empty_target._webhooks).to be_nil
    end
  end
end
