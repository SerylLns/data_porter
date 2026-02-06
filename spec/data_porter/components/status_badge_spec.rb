# frozen_string_literal: true

RSpec.describe DataPorter::Components::StatusBadge do
  def render(component)
    component.call
  end

  it "renders a span with status text" do
    html = render(described_class.new(status: "completed"))
    expect(html).to include("Completed")
    expect(html).to include("dp-badge")
  end

  it "includes status-specific CSS class" do
    html = render(described_class.new(status: "failed"))
    expect(html).to include("dp-badge--failed")
  end

  it "renders all valid statuses" do
    %w[pending parsing previewing importing completed failed].each do |status|
      html = render(described_class.new(status: status))
      expect(html).to include(status.capitalize)
    end
  end
end
