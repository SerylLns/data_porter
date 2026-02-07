# frozen_string_literal: true

RSpec.describe "progress_controller.js" do
  let(:js_path) { File.expand_path("../../app/assets/javascripts/data_porter/progress_controller.js", __dir__) }
  let(:content) { File.read(js_path) }

  it "exists" do
    expect(File.exist?(js_path)).to be true
  end

  it "imports Stimulus Controller" do
    expect(content).to include('import { Controller } from "@hotwired/stimulus"')
  end

  it "defines bar, text, and label targets" do
    expect(content).to include('static targets = ["bar", "text", "label"]')
  end

  it "defines id and url values" do
    expect(content).to include("static values = { id: Number, url: String }")
  end

  it "polls for status via fetch" do
    expect(content).to include("fetch(this.urlValue)")
  end

  it "updates progress bar width and text" do
    expect(content).to include("this.barTarget.style.width")
    expect(content).to include("this.textTarget.textContent")
  end

  it "clears timer on disconnect" do
    expect(content).to include("clearInterval(this.timer)")
  end
end
