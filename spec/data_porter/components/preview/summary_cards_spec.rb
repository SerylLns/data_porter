# frozen_string_literal: true

RSpec.describe DataPorter::Components::Preview::SummaryCards do
  def render(component)
    component.call
  end

  let(:report) do
    DataPorter::StoreModels::Report.new(
      complete_count: 10,
      partial_count: 3,
      missing_count: 2,
      create_count: 7,
      update_count: 4,
      unchanged_count: 5,
      excluded_count: 1
    )
  end

  it "renders the three status count cards" do
    html = render(described_class.new(report: report))

    expect(html).to include("10")
    expect(html).to include("Ready")
    expect(html).to include("3")
    expect(html).to include("Incomplete")
    expect(html).to include("2")
    expect(html).to include("Missing")
  end

  it "does not render a duplicates card" do
    html = render(described_class.new(report: report))

    expect(html).not_to include("Duplicates")
    expect(html).not_to include("dp-card--duplicate")
  end

  it "wraps in dp-summary-cards container" do
    html = render(described_class.new(report: report))
    expect(html).to include("dp-summary-cards")
  end

  context "when update_mode: false (default)" do
    it "does not render action cards" do
      html = render(described_class.new(report: report))

      expect(html).not_to include("dp-card--create")
      expect(html).not_to include("To update")
    end
  end

  context "when update_mode: true" do
    let(:html) { render(described_class.new(report: report, update_mode: true)) }

    it "renders create, update and unchanged cards" do
      doc = Nokogiri::HTML(html)

      expect(doc.at_css(".dp-card--create strong").text).to eq("7")
      expect(doc.at_css(".dp-card--update strong").text).to eq("4")
      expect(doc.at_css(".dp-card--unchanged strong").text).to eq("5")
      expect(doc.at_css(".dp-card--excluded strong").text).to eq("1")
    end

    it "labels the action cards" do
      expect(html).to include("To create")
      expect(html).to include("To update")
      expect(html).to include("Unchanged")
    end
  end

  context "when editable: false (default)" do
    it "does not include summary target data attribute" do
      html = render(described_class.new(report: report))
      expect(html).not_to include("data-count-key")
    end
  end

  context "when editable: true" do
    let(:html) { render(described_class.new(report: report, editable: true, update_mode: true)) }

    it "adds summary target to count elements" do
      expect(html).to include("summary")
    end

    it "adds count_key for status counts" do
      expect(html).to include('data-count-key="complete_count"')
      expect(html).to include('data-count-key="partial_count"')
      expect(html).to include('data-count-key="missing_count"')
    end

    it "adds count_key for action counts" do
      expect(html).to include('data-count-key="create_count"')
      expect(html).to include('data-count-key="update_count"')
      expect(html).to include('data-count-key="unchanged_count"')
      expect(html).to include('data-count-key="excluded_count"')
    end
  end
end
