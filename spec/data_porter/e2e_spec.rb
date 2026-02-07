# frozen_string_literal: true

require "csv"

RSpec.describe "End-to-end import workflows" do
  let(:persisted) { [] }

  before do
    DataPorter::Registry.clear
    allow(ActionCable.server).to receive(:broadcast)
  end

  after { DataPorter::Registry.clear }

  describe "CSV source" do
    let(:csv) { "Prenom,Nom,Email\nAlice,Smith,alice@example.com\nBob,Jones,bob@example.com\n" }
    let(:mapping) { { "Prenom" => "first_name", "Nom" => "last_name", "Email" => "email" } }

    before { register_contact_target }

    it "extract_headers → mapping → parse → import" do
      import = build_import("csv")

      run_extract_headers(import, content: csv)
      expect(import.status).to eq("mapping")
      expect(import.config["file_headers"]).to eq(%w[Prenom Nom Email])

      apply_mapping(import, mapping)

      run_parse(import, content: csv)
      expect(import.status).to eq("previewing")
      expect(import.records.size).to eq(2)
      expect(import.report.complete_count).to eq(2)

      run_import(import)
      expect(import.status).to eq("completed")
      expect(import.report.imported_count).to eq(2)
      expect(persisted.size).to eq(2)
      expect(persisted.first).to include(first_name: "Alice", last_name: "Smith")
      expect(persisted.last).to include(first_name: "Bob", last_name: "Jones")
    end
  end

  describe "XLSX source" do
    let(:fixture) { File.expand_path("../fixtures/contacts.xlsx", __dir__) }
    let(:mapping) { { "Prenom" => "first_name", "Nom" => "last_name", "Email" => "email" } }

    before { register_contact_target }

    it "extract_headers → mapping → parse → import with file attachment" do
      import = build_import("xlsx")
      attach_xlsx(import, fixture)

      run_extract_headers(import)
      expect(import.status).to eq("mapping")

      apply_mapping(import, mapping)

      run_parse(import)
      expect(import.status).to eq("previewing")
      expect(import.records.size).to eq(2)

      run_import(import)
      expect(import.status).to eq("completed")
      expect(import.report.imported_count).to eq(2)
      expect(persisted.size).to eq(2)
    end
  end

  describe "JSON source" do
    let(:json) { '[{"first_name":"Alice","last_name":"Smith","email":"alice@example.com"}]' }

    before { register_contact_target }

    it "parse → import (no mapping step)" do
      import = build_import("json")

      run_parse(import, content: json)
      expect(import.status).to eq("previewing")
      expect(import.records.size).to eq(1)
      expect(import.records.first).to be_complete

      run_import(import)
      expect(import.status).to eq("completed")
      expect(import.report.imported_count).to eq(1)
      expect(persisted.first).to include(first_name: "Alice")
    end
  end

  describe "API source" do
    before { register_api_target }

    it "parse → import with HTTP stub" do
      body = { contacts: [{ first_name: "Alice", email: "a@example.com" }] }.to_json
      stub_http(body)
      import = build_import("api", target_key: "e2e_api")

      run_parse(import)
      expect(import.status).to eq("previewing")
      expect(import.records.size).to eq(1)

      run_import(import)
      expect(import.status).to eq("completed")
      expect(persisted.first).to include(first_name: "Alice")
    end
  end

  describe "import with params" do
    let(:received_params) { [] }
    let(:csv) { "guest_name\nAlice\nBob\n" }

    before { register_params_target(received_params) }

    it "passes import_params to target during persist" do
      import = build_import("csv", target_key: "e2e_params",
                                   config: { "import_params" => { "hotel_id" => "42" } })

      run_parse(import, content: csv)
      run_import(import)

      expect(import.status).to eq("completed")
      expect(import.report.imported_count).to eq(2)
      expect(received_params).to all(eq({ "hotel_id" => "42" }))
    end
  end

  describe "reject rows CSV export" do
    let(:csv) { "Prenom,Nom,Email\nAlice,Smith,alice@example.com\n,Jones,\n" }
    let(:mapping) { { "Prenom" => "first_name", "Nom" => "last_name", "Email" => "email" } }

    before { register_contact_target }

    it "builds CSV from rejected records" do
      import = build_import("csv")
      run_extract_headers(import, content: csv)
      apply_mapping(import, mapping)
      run_parse(import, content: csv)

      expect(import.records.count(&:complete?)).to eq(1)
      expect(import.records.count { |r| !r.complete? }).to eq(1)

      run_import(import)
      expect(import.report.imported_count).to eq(1)

      columns = import.target_class._columns
      output = DataPorter::RejectsCsvBuilder.new(columns, import.records).generate
      rows = CSV.parse(output)

      expect(rows.first).to eq(%w[line first_name last_name email errors])
      expect(rows.size).to eq(2)
      expect(rows.last.first).to eq("2")
      expect(rows.last.last).to include("required")
    end
  end

  def build_import(source_type, target_key: "e2e_contacts", config: {})
    DataPorter::DataImport.create!(
      target_key: target_key, source_type: source_type,
      status: :pending, config: config
    )
  end

  def run_extract_headers(import, **opts)
    DataPorter::Orchestrator.new(import, **opts).extract_headers!
    import.reload
  end

  def run_parse(import, **opts)
    DataPorter::Orchestrator.new(import, **opts).parse!
    import.reload
  end

  def run_import(import)
    DataPorter::Orchestrator.new(import).import!
    import.reload
  end

  def apply_mapping(import, mapping)
    import.update!(config: import.config.merge("column_mapping" => mapping))
  end

  def attach_xlsx(import, path)
    ct = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    import.file.attach(io: File.open(path), filename: "test.xlsx", content_type: ct)
  end

  def stub_http(body)
    response = instance_double(Net::HTTPResponse, body: body)
    allow(Net::HTTP).to receive(:start).and_return(response)
  end

  def register_contact_target
    DataPorter::Registry.register(:e2e_contacts, build_contact_target(persisted))
  end

  def build_contact_target(ref)
    Class.new(DataPorter::Target) do
      label "E2E Contacts"
      model_name "Contact"
      columns do
        column :first_name, type: :string, required: true
        column :last_name, type: :string
        column :email, type: :email
      end
      csv_mapping do
        map "Prenom" => :first_name
        map "Nom" => :last_name
        map "Email" => :email
      end
      define_method(:persist) { |record, **| ref << record.data.symbolize_keys }
    end
  end

  def register_api_target
    DataPorter::Registry.register(:e2e_api, build_api_target(persisted))
  end

  def build_api_target(ref)
    Class.new(DataPorter::Target) do
      label "E2E API"
      model_name "Contact"
      columns do
        column :first_name, type: :string, required: true
        column :last_name, type: :string
        column :email, type: :email
      end
      api_config do
        endpoint "https://api.example.com/contacts"
        headers({ "Authorization" => "Bearer test" })
        response_root :contacts
      end
      define_method(:persist) { |record, **| ref << record.data.symbolize_keys }
    end
  end

  def register_params_target(params_ref)
    DataPorter::Registry.register(:e2e_params, build_params_target(params_ref))
  end

  def build_params_target(ref)
    Class.new(DataPorter::Target) do
      label "E2E Params"
      model_name "Booking"
      columns do
        column :guest_name, type: :string, required: true
      end
      params do
        param :hotel_id, type: :select, required: true
      end
      define_method(:persist) { |_record, **| ref << import_params.dup }
    end
  end
end
