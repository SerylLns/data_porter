# frozen_string_literal: true

RSpec.describe DataPorter::Components::Mapping::ColumnRow do
  def render(component)
    component.call
  end

  let(:target_fields) { [["First name", "first_name", false], ["Last name", "last_name", false]] }

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

  it "renders correct Stimulus target attribute" do
    html = render(described_class.new(file_header: "Prenom", target_fields: target_fields))
    expect(html).to include('data-data-porter--mapping-target="columnSelect"')
  end

  it "renders change action for mapping controller" do
    html = render(described_class.new(file_header: "Prenom", target_fields: target_fields))
    expect(html).to include("data-porter--mapping#onChange")
  end

  context "with required fields" do
    let(:target_fields) { [["First name", "first_name", true], ["Last name", "last_name", false]] }

    it "appends asterisk to required field labels" do
      html = render(described_class.new(file_header: "Prenom", target_fields: target_fields))
      expect(html).to include("First name *")
    end

    it "marks required options with data attribute" do
      html = render(described_class.new(file_header: "Prenom", target_fields: target_fields))
      expect(html).to include('data-required="true"')
    end
  end
end
