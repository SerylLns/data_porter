# frozen_string_literal: true

require "action_view"

RSpec.describe "data_porter/imports/show.html.erb" do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      icon "fas fa-users"
      model_name "Guest"

      columns do
        column :name, type: :string, required: true
        column :email, type: :email
      end
    end
  end

  let(:import) do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:guests, target_class)

    DataPorter::DataImport.create!(
      target_key: "guests",
      source_type: "csv",
      status: status
    )
  end

  let(:target) { target_class }
  let(:records) { import.records }
  let(:grouped) { records.group_by(&:status) }
  let(:status) { :pending }

  let(:view) { ActionView::Base.new(lookup_context, assigns, controller) }

  let(:lookup_context) do
    ActionView::LookupContext.new(
      File.expand_path("../../../../app/views", __dir__)
    )
  end

  let(:assigns) do
    { import: import, target: target, records: records, grouped: grouped }
  end

  let(:controller) do
    instance_double(DataPorter::ImportsController).tap do |c|
      allow(c).to receive(:params).and_return({})
    end
  end

  before do
    routes = DataPorter::Engine.routes
    view.class.include routes.url_helpers
    view.class.default_url_options = { host: "localhost" }
  end

  subject(:html) { view.render(template: "data_porter/imports/show") }

  it "shows the import target label" do
    expect(html).to include("Guests")
  end

  it "renders a status badge" do
    expect(html).to include("dp-badge")
  end

  context "when parsing" do
    let(:status) { :parsing }

    it "renders the progress bar" do
      expect(html).to include("dp-progress")
    end
  end

  context "when importing" do
    let(:status) { :importing }

    it "renders the progress bar" do
      expect(html).to include("dp-progress")
    end
  end

  context "when dry_running" do
    let(:status) { :dry_running }

    it "renders the progress bar" do
      expect(html).to include("dp-progress")
    end
  end

  context "when previewing" do
    let(:status) { :previewing }

    let(:import) do
      DataPorter::Registry.clear
      DataPorter::Registry.register(:guests, target_class)

      record = DataPorter::StoreModels::ImportRecord.new(
        line_number: 1,
        status: "complete",
        data: { name: "Alice", email: "alice@example.com" }
      )

      DataPorter::DataImport.create!(
        target_key: "guests",
        source_type: "csv",
        status: :previewing,
        records: [record],
        report: DataPorter::StoreModels::Report.new(
          records_count: 1,
          complete_count: 1
        )
      )
    end

    it "renders the summary cards" do
      expect(html).to include("dp-summary-cards")
    end

    it "renders the preview table" do
      expect(html).to include("dp-preview-table")
    end

    it "shows confirm button" do
      expect(html).to include("Confirm")
    end

    it "shows cancel button" do
      expect(html).to include("Cancel")
    end
  end

  context "when completed" do
    let(:status) { :completed }

    it "renders the results summary" do
      expect(html).to include("dp-results")
    end
  end

  context "when failed" do
    let(:status) { :failed }

    let(:import) do
      DataPorter::Registry.clear
      DataPorter::Registry.register(:guests, target_class)

      DataPorter::DataImport.create!(
        target_key: "guests",
        source_type: "csv",
        status: :failed,
        report: DataPorter::StoreModels::Report.new(
          error_reports: [
            DataPorter::StoreModels::Error.new(message: "Something went wrong")
          ]
        )
      )
    end

    it "renders the failure alert" do
      expect(html).to include("dp-alert")
    end

    it "shows retry button" do
      expect(html).to include("Retry")
    end
  end
end
