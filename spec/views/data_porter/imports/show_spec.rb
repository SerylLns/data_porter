# frozen_string_literal: true

require "spec_helper"
require_relative "../../../support/view_test_helper"

RSpec.describe "data_porter/imports/show.html.erb" do
  include ViewTestHelper

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

  let(:page) { 1 }
  let(:total_pages) { 1 }

  subject(:html) do
    view = build_view(
      import: import, target: target,
      records: records, grouped: grouped,
      page: page, total_pages: total_pages
    )
    view.render(template: "data_porter/imports/show")
  end

  it "shows the import target label" do
    expect(html).to include("Guests")
  end

  it "displays the target icon in the title" do
    expect(html).to include('<i class="fas fa-users"></i>')
  end

  it "displays the target icon in the details" do
    doc = Nokogiri::HTML(html)
    icons = doc.css("dd i.fas.fa-users")
    expect(icons.length).to be >= 1
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

  context "when extracting_headers" do
    let(:status) { :extracting_headers }

    it "renders the progress bar" do
      expect(html).to include("dp-progress")
    end
  end

  context "when mapping" do
    let(:status) { :mapping }

    let(:import) do
      DataPorter::Registry.clear
      DataPorter::Registry.register(:guests, target_class)

      DataPorter::DataImport.create!(
        target_key: "guests",
        source_type: "csv",
        status: :mapping,
        config: { "file_headers" => %w[Name Email] }
      )
    end

    let(:file_headers) { %w[Name Email] }
    let(:target_columns) { [%w[Name name], %w[Email email]] }
    let(:default_mapping) { {} }
    let(:templates) { [] }

    subject(:html) do
      view = build_view(
        import: import, target: target,
        records: records, grouped: grouped,
        page: page, total_pages: total_pages,
        file_headers: file_headers,
        target_columns: target_columns,
        default_mapping: default_mapping,
        templates: templates
      )
      view.render(template: "data_porter/imports/show")
    end

    it "renders the mapping form" do
      expect(html).to include("dp-mapping-form")
    end

    it "renders column rows" do
      expect(html).to include("dp-mapping-rows")
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

    it "does not show resume button without checkpoint" do
      expect(html).not_to include("Resume")
    end

    context "when resumable" do
      let(:import) do
        DataPorter::Registry.clear
        DataPorter::Registry.register(:guests, target_class)

        DataPorter::DataImport.create!(
          target_key: "guests",
          source_type: "csv",
          status: :failed,
          config: { "checkpoint" => { "processed" => 10, "created" => 8, "errored" => 2 } },
          report: DataPorter::StoreModels::Report.new(
            error_reports: [
              DataPorter::StoreModels::Error.new(message: "Connection lost")
            ]
          )
        )
      end

      it "shows resume button" do
        expect(html).to include("Resume")
      end

      it "shows retry as secondary" do
        expect(html).to include("dp-btn--secondary")
      end
    end
  end
end
