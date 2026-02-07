# frozen_string_literal: true

RSpec.describe DataPorter::Components::Shared::Pagination do
  subject(:html) { component.call }

  context "when single page" do
    let(:component) { described_class.new(page: 1, total_pages: 1, base_url: "/imports/1") }

    it "renders nothing" do
      expect(html).to eq("")
    end
  end

  context "when multiple pages" do
    let(:component) { described_class.new(page: 2, total_pages: 5, base_url: "/imports/1") }

    it "renders pagination container" do
      expect(html).to include("dp-pagination")
    end

    it "renders previous link with anchor" do
      expect(html).to include("?page=1#records")
    end

    it "renders next link with anchor" do
      expect(html).to include("?page=3#records")
    end

    it "renders page indicator" do
      expect(html).to include("Page 2 of 5")
    end
  end

  context "on first page" do
    let(:component) { described_class.new(page: 1, total_pages: 3, base_url: "/imports/1") }

    it "disables previous button" do
      expect(html).to include("dp-pagination__btn--disabled")
    end

    it "renders next link" do
      expect(html).to include("?page=2")
    end
  end

  context "on last page" do
    let(:component) { described_class.new(page: 3, total_pages: 3, base_url: "/imports/1") }

    it "renders previous link" do
      expect(html).to include("?page=2")
    end

    it "disables next button" do
      expect(html).to include("dp-pagination__btn--disabled")
    end
  end
end
