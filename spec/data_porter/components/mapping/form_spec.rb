# frozen_string_literal: true

RSpec.describe DataPorter::Components::Mapping::Form do
  def render(component)
    component.call
  end

  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Test"
      model_name "Test"

      columns do
        column :first_name, type: :string
        column :last_name, type: :string
      end

      csv_mapping do
        map "Prenom" => :first_name
        map "Nom" => :last_name
      end
    end
  end

  let(:import) do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:test, target_class)
    DataPorter::DataImport.new(id: 1, target_key: "test", source_type: "csv")
  end

  let(:file_headers) { %w[Prenom Nom] }
  let(:target_columns) { [["First name", "first_name"], ["Last name", "last_name"]] }
  let(:default_mapping) { { "Prenom" => "first_name", "Nom" => "last_name" } }
  let(:templates) { [] }

  let(:component) do
    described_class.new(
      import: import,
      action_url: "/test",
      file_headers: file_headers,
      target_columns: target_columns,
      templates: templates,
      default_mapping: default_mapping
    )
  end

  it "renders a form element" do
    html = render(component)
    expect(html).to include("<form")
    expect(html).to include("dp-mapping-form")
  end

  it "renders column rows for each header" do
    html = render(component)
    expect(html).to include("Prenom")
    expect(html).to include("Nom")
  end

  it "renders save as template checkbox" do
    html = render(component)
    expect(html).to include("save_template")
  end

  it "renders submit button" do
    html = render(component)
    expect(html).to include("Continue")
  end
end
