# frozen_string_literal: true

RSpec.describe DataPorter::Components::Progress::Bar do
  def render(component)
    component.call
  end

  it "renders a progress bar with Stimulus data attributes" do
    html = render(described_class.new(import_id: 42))

    expect(html).to include("dp-progress")
    expect(html).to include("data-controller")
    expect(html).to include("data-porter--progress")
    expect(html).to include("42")
  end

  it "renders bar and text targets" do
    html = render(described_class.new(import_id: 1))

    expect(html).to include("data-data-porter--progress-target=\"bar\"")
    expect(html).to include("data-data-porter--progress-target=\"text\"")
  end
end
