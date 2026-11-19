# frozen_string_literal: true

RSpec.describe DataPorter::Components::Preview::ActionFilter do
  def render_doc(current: nil)
    Nokogiri::HTML(described_class.new(current: current, base_url: "/data_porter/1").call)
  end

  it "renders a link per filter" do
    labels = render_doc.css(".dp-filter").map(&:text)

    expect(labels).to eq(["All", "To create", "To update", "Unchanged", "Excluded"])
  end

  it "links each filter to the records anchor" do
    hrefs = render_doc.css(".dp-filter").map { |link| link["href"] }

    expect(hrefs).to eq(
      [
        "/data_porter/1#records",
        "/data_porter/1?filter=create#records",
        "/data_porter/1?filter=update#records",
        "/data_porter/1?filter=unchanged#records",
        "/data_porter/1?filter=excluded#records"
      ]
    )
  end

  it "marks All as active without a filter" do
    expect(render_doc.at_css(".dp-filter--active").text).to eq("All")
  end

  it "marks the current filter as active" do
    active = render_doc(current: "update").at_css(".dp-filter--active")

    expect([active.text, active["aria-current"]]).to eq(["To update", "page"])
  end
end
