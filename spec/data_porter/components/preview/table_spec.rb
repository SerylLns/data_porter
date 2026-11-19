# frozen_string_literal: true

RSpec.describe DataPorter::Components::Preview::Table do
  def render(component)
    component.call
  end

  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"

      columns do
        column :first_name, type: :string, required: true
        column :last_name, type: :string
      end
    end
  end

  let(:record) do
    DataPorter::StoreModels::ImportRecord.new(
      line_number: 1,
      status: "complete",
      data: { "first_name" => "Alice", "last_name" => "Smith" }
    )
  end

  let(:error_record) do
    r = DataPorter::StoreModels::ImportRecord.new(
      line_number: 2,
      status: "missing",
      data: { "first_name" => "", "last_name" => "Jones" }
    )
    r.add_error("First name is required")
    r
  end

  it "renders column headers from target" do
    html = render(described_class.new(columns: target_class._columns, records: [record]))

    expect(html).to include("First name")
    expect(html).to include("Last name")
  end

  it "renders record data in rows" do
    html = render(described_class.new(columns: target_class._columns, records: [record]))

    expect(html).to include("Alice")
    expect(html).to include("Smith")
  end

  it "renders error messages" do
    html = render(described_class.new(columns: target_class._columns, records: [error_record]))

    expect(html).to include("First name is required")
  end

  it "includes status-specific row class" do
    html = render(described_class.new(columns: target_class._columns, records: [record]))
    expect(html).to include("dp-row--complete")
  end

  it "wraps in dp-preview-table container" do
    html = render(described_class.new(columns: target_class._columns, records: [record]))
    expect(html).to include("dp-preview-table")
  end

  context "when editable: false (default)" do
    it "does not include Stimulus controller data attribute" do
      html = render(described_class.new(columns: target_class._columns, records: [record]))
      expect(html).not_to include("data-controller")
    end

    it "does not include editable cell class" do
      html = render(described_class.new(columns: target_class._columns, records: [record]))
      expect(html).not_to include("dp-cell--editable")
    end
  end

  context "when editable: true" do
    let(:update_url) { "/data_porter/1/update_record" }

    let(:html) do
      render(described_class.new(
               columns: target_class._columns,
               records: [record, error_record],
               editable: true,
               update_url: update_url
             ))
    end

    it "adds Stimulus controller to wrapper" do
      expect(html).to include('data-controller="data-porter--inline-edit"')
    end

    it "adds update URL value" do
      expect(html).to include(update_url)
    end

    it "adds editable class to data cells" do
      expect(html).to include("dp-cell--editable")
    end

    it "adds click action to data cells" do
      expect(html).to include("click->data-porter--inline-edit#edit")
    end

    it "adds cell target to data cells" do
      expect(html).to include("cell")
    end

    it "adds data-value to cells" do
      expect(html).to include('data-value="Alice"')
    end

    it "adds data-line-number to cells" do
      expect(html).to include('data-line-number="1"')
    end

    it "adds data-column to cells" do
      expect(html).to include('data-column="first_name"')
    end

    it "adds errors target to errors cell" do
      expect(html).to include("errors")
    end

    it "adds line-number to rows" do
      expect(html).to include('data-line-number="2"')
    end
  end

  context "with update mode" do
    let(:changed_record) do
      DataPorter::StoreModels::ImportRecord.new(
        line_number: 3, status: "complete", action: "update",
        data: { "first_name" => "Alice", "last_name" => "Smith" },
        diff: { "first_name" => %w[Alicia Alice] }
      )
    end

    let(:pending_record) do
      DataPorter::StoreModels::ImportRecord.new(line_number: 4, status: "partial", data: { "first_name" => "Bob" })
    end

    def render_doc(**options)
      records = [changed_record, pending_record]
      Nokogiri::HTML(render(described_class.new(columns: target_class._columns, records: records, **options)))
    end

    context "when update_mode: false (default)" do
      let(:doc) { render_doc }

      it "does not render the action column" do
        expect(doc.css(".dp-cell--action")).to be_empty
      end

      it "does not render diffs" do
        expect(doc.css(".dp-cell--changed")).to be_empty
      end
    end

    context "when update_mode: true" do
      let(:doc) { render_doc(update_mode: true) }

      it "renders an action header" do
        expect(doc.css("th").map(&:text)).to include("Action")
      end

      it "renders the record action badge" do
        expect(doc.at_css(".dp-cell--action .dp-action--update").text).to eq("Update")
      end

      it "renders an empty action cell when the record has no action" do
        expect(doc.css(".dp-cell--action")[1].text).to eq("")
      end

      it "renders old and new values in changed cells" do
        cell = doc.at_css("td.dp-cell--changed")

        expect([cell.at_css(".dp-diff__old").text, cell.at_css(".dp-diff__new").text]).to eq(%w[Alicia Alice])
      end

      it "renders other cells as plain values" do
        expect(doc.css("td.dp-cell--changed").size).to eq(1)
      end
    end

    context "when editable and update_mode: true" do
      let(:doc) { render_doc(update_mode: true, editable: true, update_url: "/u") }

      it "keeps the new value as the editable value of changed cells" do
        expect(doc.at_css("td.dp-cell--changed")["data-value"]).to eq("Alice")
      end

      it "exposes the old value of changed cells" do
        expect(doc.at_css("td.dp-cell--changed")["data-old-value"]).to eq("Alicia")
      end

      it "exposes action labels to the inline edit controller" do
        labels = JSON.parse(doc.at_css(".dp-preview-table")["data-data-porter--inline-edit-action-labels-value"])

        expect(labels).to eq("create" => "Create", "update" => "Update", "unchanged" => "Unchanged")
      end
    end
  end
end
