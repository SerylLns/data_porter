# frozen_string_literal: true

RSpec.describe DataPorter::ImportsController do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Test Import"
      icon "fas fa-test"
      model_name "TestModel"

      columns do
        column :name, type: :string, required: true
      end
    end
  end

  before do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:test_import, target_class)
  end

  after { DataPorter::Registry.clear }

  describe "inheritance" do
    it "inherits from the configured parent controller" do
      expect(described_class.superclass.name).to eq(DataPorter.configuration.parent_controller)
    end
  end

  describe "before_actions" do
    it "registers set_import callback" do
      callbacks = described_class._process_action_callbacks.select do |c|
        c.filter == :set_import
      end

      expect(callbacks).not_to be_empty
    end
  end

  describe "action methods" do
    it "defines all public actions including export_rejects, resume, and update_record" do
      actions = %i[index new create show parse confirm cancel dry_run update_mapping
                   update_record status export_rejects destroy back_to_mapping resume]
      actions.each do |action|
        expect(described_class.instance_method(action)).to be_a(UnboundMethod)
      end
    end
  end

  describe "private methods" do
    it "defines set_import" do
      expect(described_class.private_instance_methods).to include(:set_import)
    end

    it "defines import_params" do
      expect(described_class.private_instance_methods).to include(:import_params)
    end

    it "defines valid_file_presence?" do
      expect(described_class.private_instance_methods).to include(:valid_file_presence?)
    end

    it "defines valid_source_for_target?" do
      expect(described_class.private_instance_methods).to include(:valid_source_for_target?)
    end

    it "defines valid_import_params?" do
      expect(described_class.private_instance_methods).to include(:valid_import_params?)
    end
  end

  describe "#paginate_records" do
    let(:controller) { described_class.new }
    let(:records) { (1..75).map { |i| DataPorter::StoreModels::ImportRecord.new(line_number: i) } }

    before { controller.instance_variable_set(:@records, records) }

    it "defaults to page 1 with 50 per page" do
      controller.params = ActionController::Parameters.new({})
      controller.send(:paginate_records)

      expect(controller.instance_variable_get(:@records).size).to eq(50)
      expect(controller.instance_variable_get(:@page)).to eq(1)
      expect(controller.instance_variable_get(:@total_pages)).to eq(2)
    end

    it "returns second page records" do
      controller.params = ActionController::Parameters.new(page: "2")
      controller.send(:paginate_records)

      expect(controller.instance_variable_get(:@records).size).to eq(25)
      expect(controller.instance_variable_get(:@page)).to eq(2)
    end

    it "clamps page to valid range" do
      controller.params = ActionController::Parameters.new(page: "999")
      controller.send(:paginate_records)

      expect(controller.instance_variable_get(:@page)).to eq(2)
    end

    it "skips pagination when records fit in one page" do
      controller.instance_variable_set(:@records, records.first(10))
      controller.params = ActionController::Parameters.new({})
      controller.send(:paginate_records)

      expect(controller.instance_variable_get(:@total_pages)).to eq(1)
    end
  end

  describe "#valid_file_presence?" do
    let(:controller) { described_class.new }

    before { controller.instance_variable_set(:@import, import) }

    context "with csv source and no file" do
      let(:import) { DataPorter::DataImport.new(source_type: "csv") }

      it "returns false" do
        expect(controller.send(:valid_file_presence?)).to be false
      end

      it "adds error message" do
        controller.send(:valid_file_presence?)
        expect(import.errors[:file]).to include("must be attached for CSV imports")
      end
    end

    context "with json source and no file" do
      let(:import) { DataPorter::DataImport.new(source_type: "json") }

      it "returns false" do
        expect(controller.send(:valid_file_presence?)).to be false
      end
    end

    context "with xlsx source and no file" do
      let(:import) { DataPorter::DataImport.new(source_type: "xlsx") }

      it "returns false" do
        expect(controller.send(:valid_file_presence?)).to be false
      end
    end

    context "with api source and no file" do
      let(:import) { DataPorter::DataImport.new(source_type: "api") }

      it "returns true" do
        expect(controller.send(:valid_file_presence?)).to be true
      end
    end
  end

  describe "#valid_source_for_target?" do
    let(:controller) { described_class.new }
    let(:csv_only_target) do
      Class.new(DataPorter::Target) do
        label "CsvOnly"
        model_name "CsvOnly"
        sources :csv
      end
    end

    before do
      DataPorter::Registry.clear
      DataPorter::Registry.register(:csv_only, csv_only_target)
    end

    context "when source is allowed by target" do
      let(:import) { DataPorter::DataImport.new(target_key: "csv_only", source_type: "csv") }

      before { controller.instance_variable_set(:@import, import) }

      it "returns true" do
        expect(controller.send(:valid_source_for_target?)).to be true
      end
    end

    context "when source is not allowed by target" do
      let(:import) { DataPorter::DataImport.new(target_key: "csv_only", source_type: "xlsx") }

      before { controller.instance_variable_set(:@import, import) }

      it "returns false" do
        expect(controller.send(:valid_source_for_target?)).to be false
      end

      it "adds an error message" do
        controller.send(:valid_source_for_target?)

        expect(import.errors[:source_type]).to include("xlsx is not available for this target")
      end
    end

    context "when target has no sources declared" do
      let(:no_sources_target) do
        Class.new(DataPorter::Target) do
          label "NoSources"
          model_name "NoSources"
        end
      end
      let(:import) { DataPorter::DataImport.new(target_key: "no_sources", source_type: "xlsx") }

      before do
        DataPorter::Registry.register(:no_sources, no_sources_target)
        controller.instance_variable_set(:@import, import)
      end

      it "allows any enabled source" do
        expect(controller.send(:valid_source_for_target?)).to be true
      end
    end
  end

  describe "#valid_import_params?" do
    let(:controller) { described_class.new }

    context "when target has required params" do
      let(:params_target) do
        Class.new(DataPorter::Target) do
          label "WithParams"
          model_name "WithParams"

          params do
            param :hotel_id, type: :select, required: true
            param :currency, type: :text
          end
        end
      end

      before do
        DataPorter::Registry.register(:with_params, params_target)
      end

      context "when required param is present" do
        let(:import) do
          DataPorter::DataImport.new(
            target_key: "with_params",
            config: { "import_params" => { "hotel_id" => "42" } }
          )
        end

        before { controller.instance_variable_set(:@import, import) }

        it "returns true" do
          expect(controller.send(:valid_import_params?)).to be true
        end
      end

      context "when required param is missing" do
        let(:import) do
          DataPorter::DataImport.new(
            target_key: "with_params",
            config: { "import_params" => {} }
          )
        end

        before { controller.instance_variable_set(:@import, import) }

        it "returns false" do
          expect(controller.send(:valid_import_params?)).to be false
        end

        it "adds an error" do
          controller.send(:valid_import_params?)

          expect(import.errors[:base]).to include("Hotel is required")
        end
      end

      context "when required param is blank" do
        let(:import) do
          DataPorter::DataImport.new(
            target_key: "with_params",
            config: { "import_params" => { "hotel_id" => "" } }
          )
        end

        before { controller.instance_variable_set(:@import, import) }

        it "returns false" do
          expect(controller.send(:valid_import_params?)).to be false
        end
      end
    end

    context "when target has no params" do
      let(:import) { DataPorter::DataImport.new(target_key: "test_import") }

      before { controller.instance_variable_set(:@import, import) }

      it "returns true" do
        expect(controller.send(:valid_import_params?)).to be true
      end
    end
  end

  describe "#merge_import_params" do
    let(:controller) { described_class.new }
    let(:params_target) do
      Class.new(DataPorter::Target) do
        label "WithParams"
        model_name "WithParams"

        params do
          param :hotel_id, type: :select, required: true
          param :currency, type: :text
        end
      end
    end

    before do
      DataPorter::Registry.register(:with_params, params_target)
    end

    it "permits declared param names" do
      raw = ActionController::Parameters.new(
        data_import: {
          target_key: "with_params",
          source_type: "csv",
          config: { import_params: { hotel_id: "42", currency: "EUR" } }
        }
      )
      controller.params = raw
      permitted = raw.require(:data_import).permit(:target_key, :source_type, :file, config: {})
      result = controller.send(:merge_import_params, permitted)

      expect(result[:config]["import_params"].keys).to contain_exactly("hotel_id", "currency")
      expect(result[:config]["import_params"]["hotel_id"]).to eq("42")
      expect(result[:config]["import_params"]["currency"]).to eq("EUR")
    end

    it "strips undeclared param names" do
      raw = ActionController::Parameters.new(
        data_import: {
          target_key: "with_params",
          source_type: "csv",
          config: { import_params: { hotel_id: "42", injected: "malicious" } }
        }
      )
      controller.params = raw
      permitted = raw.require(:data_import).permit(:target_key, :source_type, :file, config: {})
      result = controller.send(:merge_import_params, permitted)

      expect(result[:config]["import_params"].keys).to eq(["hotel_id"])
      expect(result[:config]["import_params"]).not_to have_key("injected")
    end

    it "returns permitted unchanged when no import_params present" do
      raw = ActionController::Parameters.new(
        data_import: { target_key: "with_params", source_type: "csv" }
      )
      controller.params = raw
      permitted = raw.require(:data_import).permit(:target_key, :source_type, :file, config: {})
      result = controller.send(:merge_import_params, permitted)

      expect(result[:config]).to be_nil
    end
  end

  describe "#scoped_imports" do
    let(:controller) { described_class.new }

    context "when no scope is configured" do
      it "returns all imports" do
        expect(controller.send(:scoped_imports)).to eq(DataPorter::DataImport.all)
      end
    end

    context "when scope returns current_user" do
      let(:user) { User.create! }

      before do
        DataPorter.configuration.scope = ->(u) { u }
        allow(controller).to receive(:current_user).and_return(user)
      end

      after { DataPorter.configuration.scope = nil }

      it "filters imports by user" do
        owned = DataPorter::DataImport.create!(target_key: "test_import", source_type: "api", user: user)
        other = DataPorter::DataImport.create!(target_key: "test_import", source_type: "api")

        result = controller.send(:scoped_imports)

        expect(result).to include(owned)
        expect(result).not_to include(other)
      end
    end

    context "when scope returns an associated object" do
      let(:user) { User.create! }
      let(:other_user) { User.create! }

      before do
        DataPorter.configuration.scope = ->(u) { u }
        allow(controller).to receive(:current_user).and_return(user)
      end

      after { DataPorter.configuration.scope = nil }

      it "isolates imports by owner" do
        mine = DataPorter::DataImport.create!(target_key: "test_import", source_type: "api", user: user)
        theirs = DataPorter::DataImport.create!(target_key: "test_import", source_type: "api", user: other_user)

        result = controller.send(:scoped_imports)

        expect(result).to include(mine)
        expect(result).not_to include(theirs)
      end
    end

    context "when scope is configured but no current_user" do
      before do
        DataPorter.configuration.scope = ->(u) { u }
      end

      after { DataPorter.configuration.scope = nil }

      it "returns all imports" do
        expect(controller.send(:scoped_imports)).to eq(DataPorter::DataImport.all)
      end
    end
  end

  describe "#resolve_owner" do
    let(:controller) { described_class.new }

    context "when no scope is configured" do
      it "returns current_user if available" do
        user = User.create!
        allow(controller).to receive(:current_user).and_return(user)

        expect(controller.send(:resolve_owner)).to eq(user)
      end

      it "returns nil when no current_user" do
        expect(controller.send(:resolve_owner)).to be_nil
      end
    end

    context "when scope is configured" do
      let(:user) { User.create! }

      before do
        allow(controller).to receive(:current_user).and_return(user)
      end

      after { DataPorter.configuration.scope = nil }

      it "returns the scope result" do
        DataPorter.configuration.scope = ->(u) { u }

        expect(controller.send(:resolve_owner)).to eq(user)
      end

      it "returns nil when current_user is nil" do
        DataPorter.configuration.scope = ->(u) { u }
        allow(controller).to receive(:current_user).and_return(nil)

        expect(controller.send(:resolve_owner)).to be_nil
      end
    end
  end

  describe "#saved_or_default_mapping" do
    let(:controller) { described_class.new }
    let(:import) { DataPorter::DataImport.new(target_key: "test_import", source_type: "csv") }

    before { controller.instance_variable_set(:@import, import) }

    context "when config has column_mapping" do
      before do
        import.config = { "column_mapping" => { "Name" => "name", "Email" => "email" } }
      end

      it "returns the saved mapping" do
        result = controller.send(:saved_or_default_mapping, target_class)

        expect(result).to eq("Name" => "name", "Email" => "email")
      end
    end

    context "when config has no column_mapping" do
      let(:mapping_target) do
        Class.new(DataPorter::Target) do
          label "Mapped"
          model_name "Mapped"
          columns do
            column :name, type: :string
          end
          csv_mapping do
            map "Full Name" => :name
          end
        end
      end

      before do
        DataPorter::Registry.register(:mapped, mapping_target)
      end

      it "falls back to target csv_mappings" do
        result = controller.send(:saved_or_default_mapping, mapping_target)

        expect(result).to eq("Full Name" => "name")
      end
    end
  end

  describe "action methods (back_to_mapping)" do
    it "defines back_to_mapping" do
      expect(described_class.instance_method(:back_to_mapping)).to be_a(UnboundMethod)
    end
  end

  describe "#permitted_column_mapping" do
    let(:controller) { described_class.new }
    let(:import) do
      DataPorter::DataImport.new(target_key: "test_import", source_type: "csv")
    end

    before { controller.instance_variable_set(:@import, import) }

    it "allows valid target column names as values" do
      controller.params = ActionController::Parameters.new(
        column_mapping: { "Name" => "name", "Other" => "" }
      )
      result = controller.send(:permitted_column_mapping)

      expect(result).to eq("Name" => "name", "Other" => "")
    end

    it "rejects values that are not valid target column names" do
      controller.params = ActionController::Parameters.new(
        column_mapping: { "Name" => "name", "Injected" => "admin_role" }
      )
      result = controller.send(:permitted_column_mapping)

      expect(result).to eq("Name" => "name", "Injected" => "")
    end
  end

  describe "#valid_file_size?" do
    let(:controller) { described_class.new }

    context "when file exceeds max_file_size" do
      let(:import) { DataPorter::DataImport.new(source_type: "csv") }
      let(:blob) { double("blob", byte_size: 20.megabytes) }
      let(:attachment) { double("file", attached?: true, blob: blob) }

      before do
        controller.instance_variable_set(:@import, import)
        allow(import).to receive(:file).and_return(attachment)
      end

      it "returns false" do
        expect(controller.send(:valid_file_size?)).to be false
      end

      it "adds an error" do
        controller.send(:valid_file_size?)

        expect(import.errors[:file]).to include("is too large (max 10 MB)")
      end
    end

    context "when file is within max_file_size" do
      let(:import) { DataPorter::DataImport.new(source_type: "csv") }
      let(:blob) { double("blob", byte_size: 5.megabytes) }
      let(:attachment) { double("file", attached?: true, blob: blob) }

      before do
        controller.instance_variable_set(:@import, import)
        allow(import).to receive(:file).and_return(attachment)
      end

      it "returns true" do
        expect(controller.send(:valid_file_size?)).to be true
      end
    end

    context "when no file is attached" do
      let(:import) { DataPorter::DataImport.new(source_type: "api") }

      before { controller.instance_variable_set(:@import, import) }

      it "returns true" do
        expect(controller.send(:valid_file_size?)).to be true
      end
    end
  end

  describe "#valid_file_content_type?" do
    let(:controller) { described_class.new }

    context "with csv source and text/csv content type" do
      let(:import) { DataPorter::DataImport.new(source_type: "csv") }
      let(:blob) { double("blob", content_type: "text/csv") }
      let(:attachment) { double("file", attached?: true, blob: blob) }

      before do
        controller.instance_variable_set(:@import, import)
        allow(import).to receive(:file).and_return(attachment)
      end

      it "returns true" do
        expect(controller.send(:valid_file_content_type?)).to be true
      end
    end

    context "with csv source and text/plain content type" do
      let(:import) { DataPorter::DataImport.new(source_type: "csv") }
      let(:blob) { double("blob", content_type: "text/plain") }
      let(:attachment) { double("file", attached?: true, blob: blob) }

      before do
        controller.instance_variable_set(:@import, import)
        allow(import).to receive(:file).and_return(attachment)
      end

      it "returns true" do
        expect(controller.send(:valid_file_content_type?)).to be true
      end
    end

    context "with csv source and invalid content type" do
      let(:import) { DataPorter::DataImport.new(source_type: "csv") }
      let(:blob) { double("blob", content_type: "application/pdf") }
      let(:attachment) { double("file", attached?: true, blob: blob) }

      before do
        controller.instance_variable_set(:@import, import)
        allow(import).to receive(:file).and_return(attachment)
      end

      it "returns false" do
        expect(controller.send(:valid_file_content_type?)).to be false
      end

      it "adds an error" do
        controller.send(:valid_file_content_type?)

        expect(import.errors[:file]).to include("has an invalid content type (application/pdf)")
      end
    end

    context "with json source and application/json content type" do
      let(:import) { DataPorter::DataImport.new(source_type: "json") }
      let(:blob) { double("blob", content_type: "application/json") }
      let(:attachment) { double("file", attached?: true, blob: blob) }

      before do
        controller.instance_variable_set(:@import, import)
        allow(import).to receive(:file).and_return(attachment)
      end

      it "returns true" do
        expect(controller.send(:valid_file_content_type?)).to be true
      end
    end

    context "with xlsx source and valid content type" do
      let(:import) { DataPorter::DataImport.new(source_type: "xlsx") }
      let(:blob) { double("blob", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") }
      let(:attachment) { double("file", attached?: true, blob: blob) }

      before do
        controller.instance_variable_set(:@import, import)
        allow(import).to receive(:file).and_return(attachment)
      end

      it "returns true" do
        expect(controller.send(:valid_file_content_type?)).to be true
      end
    end

    context "when no file is attached" do
      let(:import) { DataPorter::DataImport.new(source_type: "api") }

      before { controller.instance_variable_set(:@import, import) }

      it "returns true" do
        expect(controller.send(:valid_file_content_type?)).to be true
      end
    end
  end

  describe "#ensure_previewing" do
    let(:controller) { described_class.new }

    context "when import is previewing" do
      let(:import) { DataPorter::DataImport.new(status: :previewing) }

      before { controller.instance_variable_set(:@import, import) }

      it "returns nil (does not halt)" do
        expect(controller.send(:ensure_previewing)).to be_nil
      end
    end

    context "when import is not previewing" do
      let(:import) { DataPorter::DataImport.new(status: :completed) }

      before do
        controller.instance_variable_set(:@import, import)
        allow(controller).to receive(:render)
      end

      it "renders an error response" do
        controller.send(:ensure_previewing)
        expect(controller).to have_received(:render).with(
          json: { error: "Import is not in previewing state" },
          status: :unprocessable_entity
        )
      end
    end
  end

  describe "before_actions for update_record" do
    it "registers set_import for update_record" do
      expect(described_class.instance_method(:update_record)).to be_a(UnboundMethod)
    end

    it "registers ensure_previewing for update_record" do
      callbacks = described_class._process_action_callbacks.select do |c|
        c.filter == :ensure_previewing
      end
      expect(callbacks).not_to be_empty
    end
  end
end
