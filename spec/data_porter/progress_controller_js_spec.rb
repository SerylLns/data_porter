# frozen_string_literal: true

RSpec.describe "progress_controller.js" do
  let(:js_path) { File.expand_path("../../app/javascript/data_porter/progress_controller.js", __dir__) }
  let(:content) { File.read(js_path) }

  it "exists" do
    expect(File.exist?(js_path)).to be true
  end

  it "imports Stimulus Controller" do
    expect(content).to include('import { Controller } from "@hotwired/stimulus"')
  end

  it "imports ActionCable consumer" do
    expect(content).to include('import { createConsumer } from "@rails/actioncable"')
  end

  it "defines bar and text targets" do
    expect(content).to include('static targets = ["bar", "text"]')
  end

  it "defines id value" do
    expect(content).to include("static values = { id: Number }")
  end

  it "subscribes to ImportChannel on connect" do
    expect(content).to include("DataPorter::ImportChannel")
  end

  it "unsubscribes on disconnect" do
    expect(content).to include("this.subscription?.unsubscribe()")
  end

  it "updates progress bar width and text" do
    expect(content).to include("this.barTarget.style.width")
    expect(content).to include("this.textTarget.textContent")
  end
end
