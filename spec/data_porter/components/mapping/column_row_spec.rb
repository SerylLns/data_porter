# frozen_string_literal: true

RSpec.describe DataPorter::Components::Mapping::ColumnRow do
  def render(component)
    component.call
  end

  let(:target_fields) { [["First name", "first_name"], ["Last name", "last_name"]] }

  it "renders the file header" do
    html = render(described_class.new(file_header: "Prenom", target_fields: target_fields))
    expect(html).to include("Prenom")
  end

  it "renders a select with target fields" do
    html = render(described_class.new(file_header: "Prenom", target_fields: target_fields))
    expect(html).to include("first_name")
    expect(html).to include("last_name")
  end

  it "pre-selects the matching field" do
    html = render(described_class.new(file_header: "Prenom", target_fields: target_fields, selected: "first_name"))
    expect(html).to include("selected")
  end

  it "uses dp-mapping-row class" do
    html = render(described_class.new(file_header: "Prenom", target_fields: target_fields))
    expect(html).to include("dp-mapping-row")
  end
end
