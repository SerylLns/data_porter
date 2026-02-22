# frozen_string_literal: true

RSpec.describe "inline_edit_controller.js" do
  let(:js_path) { File.expand_path("../../app/assets/javascripts/data_porter/inline_edit_controller.js", __dir__) }
  let(:content) { File.read(js_path) }

  it "exists" do
    expect(File.exist?(js_path)).to be true
  end

  it "imports Stimulus Controller" do
    expect(content).to include('import { Controller } from "@hotwired/stimulus"')
  end

  it "defines cell, errors, and summary targets" do
    expect(content).to include('static targets = ["cell", "errors", "summary"]')
  end

  it "defines updateUrl value" do
    expect(content).to include("static values = { updateUrl: String }")
  end

  it "creates an input element on edit" do
    expect(content).to include("dp-inline-input")
  end

  it "sends PATCH request to updateUrl" do
    expect(content).to include("this.updateUrlValue")
    expect(content).to include('method: "PATCH"')
  end

  it "handles Enter key to save" do
    expect(content).to include('"Enter"')
  end

  it "handles Escape key to cancel" do
    expect(content).to include('"Escape"')
  end

  it "handles Tab key to move to next cell" do
    expect(content).to include('"Tab"')
    expect(content).to include("moveToNext")
  end

  it "applies saving class during PATCH" do
    expect(content).to include("dp-cell--saving")
  end

  it "applies success class after response" do
    expect(content).to include("dp-cell--success")
  end

  it "applies error class on failure" do
    expect(content).to include("dp-cell--error")
  end

  it "updates row status from response" do
    expect(content).to include("updateRowStatus")
  end

  it "updates errors cell from response" do
    expect(content).to include("updateErrors")
  end

  it "updates summary cards from response" do
    expect(content).to include("updateSummary")
  end

  it "includes CSRF token in headers" do
    expect(content).to include("csrf-token")
  end

  it "skips save when value unchanged" do
    expect(content).to include("newValue === original")
  end

  it "adds editing class while input is visible" do
    expect(content).to include("dp-cell--editing")
  end

  it "removes editing class on blur" do
    expect(content).to include('cell.classList.remove("dp-cell--editing")')
  end
end
