# frozen_string_literal: true

RSpec.describe DataPorter::Components::Mapping::TemplateSelect do
  def render(component)
    component.call
  end

  let(:templates) do
    [
      DataPorter::MappingTemplate.new(id: 1, name: "French", mapping: { "Prenom" => "first_name" }),
      DataPorter::MappingTemplate.new(id: 2, name: "German", mapping: { "Vorname" => "first_name" })
    ]
  end

  it "renders a select element" do
    html = render(described_class.new(templates: templates))
    expect(html).to include("<select")
    expect(html).to include("dp-mapping-template")
  end

  it "renders template options" do
    html = render(described_class.new(templates: templates))
    expect(html).to include("French")
    expect(html).to include("German")
  end

  it "includes mapping data as JSON attribute" do
    html = render(described_class.new(templates: templates))
    expect(html).to include("data-mapping")
  end

  it "renders empty option prompt" do
    html = render(described_class.new(templates: templates))
    expect(html).to include("Select a template")
  end
end
