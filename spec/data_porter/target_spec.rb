# frozen_string_literal: true

RSpec.describe DataPorter::Target do
  let(:target_class) do
    Class.new(described_class) do
      label "Guests"
      model_name "Guest"
      icon "fas fa-users"
      sources :csv, :json

      columns do
        column :first_name, type: :string, required: true
        column :last_name,  type: :string, required: true
        column :email,      type: :email
      end

      csv_mapping do
        map "Prenom" => :first_name
        map "Nom"    => :last_name
      end

      deduplicate_by :email
    end
  end

  describe "DSL class methods" do
    it "sets the label" do
      expect(target_class._label).to eq("Guests")
    end

    it "sets the model name" do
      expect(target_class._model_name).to eq("Guest")
    end

    it "sets the icon" do
      expect(target_class._icon).to eq("fas fa-users")
    end

    it "sets the sources" do
      expect(target_class._sources).to eq(%i[csv json])
    end

    it "defines columns" do
      expect(target_class._columns.size).to eq(3)
    end

    it "stores column attributes" do
      col = target_class._columns.first

      expect(col.name).to eq(:first_name)
      expect(col.type).to eq(:string)
      expect(col.required).to be true
    end

    it "stores csv mappings" do
      expect(target_class._csv_mappings).to eq(
        "Prenom" => :first_name,
        "Nom" => :last_name
      )
    end

    it "stores dedup keys" do
      expect(target_class._dedup_keys).to eq([:email])
    end
  end

  describe "column label" do
    it "defaults to humanized name" do
      col = target_class._columns.first
      expect(col.label).to eq("First name")
    end

    it "accepts custom label" do
      klass = Class.new(described_class) do
        columns do
          column :full_name, type: :string, label: "Full Name"
        end
      end

      expect(klass._columns.first.label).to eq("Full Name")
    end
  end

  describe "auto-registration" do
    before { DataPorter::Registry.clear }

    it "registers named subclasses when label is called" do
      klass = Class.new(described_class)
      stub_const("ContactTarget", klass)
      klass.label("Contacts")

      expect(DataPorter::Registry.find(:contact)).to eq(klass)
    end

    it "skips anonymous classes" do
      Class.new(described_class) { label "Anon" }

      expect(DataPorter::Registry.available).to be_empty
    end
  end

  describe "params DSL" do
    let(:params_target) do
      Class.new(described_class) do
        params do
          param :hotel_id, type: :select, label: "Hotel", required: true,
                           collection: -> { [%w[Hilton 1], %w[Marriott 2]] }
          param :currency, type: :text, default: "EUR"
        end
      end
    end

    it "stores param definitions" do
      expect(params_target._params.size).to eq(2)
    end

    it "stores param attributes" do
      p = params_target._params.first

      expect(p.name).to eq(:hotel_id)
      expect(p.type).to eq(:select)
      expect(p.required).to be true
      expect(p.label).to eq("Hotel")
    end

    it "stores collection callable" do
      p = params_target._params.first

      expect(p.collection.call).to eq([%w[Hilton 1], %w[Marriott 2]])
    end

    it "stores default values" do
      p = params_target._params.last

      expect(p.default).to eq("EUR")
    end

    it "defaults _params to nil when not declared" do
      expect(target_class._params).to be_nil
    end
  end

  describe "import_params accessor" do
    let(:target) { target_class.new }

    it "defaults to empty hash" do
      expect(target.import_params).to eq({})
    end

    it "can be set via writer" do
      target.import_params = { "hotel_id" => "1" }

      expect(target.import_params).to eq("hotel_id" => "1")
    end
  end

  describe "bulk_mode DSL" do
    it "defaults _bulk_config to nil" do
      expect(target_class._bulk_config).to be_nil
    end

    it "stores bulk config with defaults" do
      klass = Class.new(described_class) do
        model_name "Guest"
        bulk_mode
      end

      expect(klass._bulk_config).to eq(batch_size: 500, on_conflict: :retry_per_record)
    end

    it "accepts custom batch_size" do
      klass = Class.new(described_class) do
        model_name "Guest"
        bulk_mode batch_size: 200
      end

      expect(klass._bulk_config[:batch_size]).to eq(200)
    end

    it "accepts on_conflict: :fail_batch" do
      klass = Class.new(described_class) do
        model_name "Guest"
        bulk_mode on_conflict: :fail_batch
      end

      expect(klass._bulk_config[:on_conflict]).to eq(:fail_batch)
    end
  end

  describe "default persist_batch" do
    let(:model_class) { class_double("Guest") }

    before do
      stub_const("Guest", model_class)
    end

    it "calls insert_all on the model class with timestamps" do
      klass = Class.new(described_class) do
        model_name "Guest"
        bulk_mode
      end

      records = [
        DataPorter::StoreModels::ImportRecord.new(data: { "name" => "Alice" }),
        DataPorter::StoreModels::ImportRecord.new(data: { "name" => "Bob" })
      ]

      allow(model_class).to receive(:insert_all)
      target = klass.new

      target.persist_batch(records, context: nil)

      expect(model_class).to have_received(:insert_all) do |rows|
        expect(rows.size).to eq(2)
        expect(rows.first).to include("name" => "Alice")
        expect(rows.first).to have_key("created_at")
        expect(rows.first).to have_key("updated_at")
      end
    end

    it "raises Error when model_name is not defined" do
      klass = Class.new(described_class) do
        bulk_mode
      end
      target = klass.new

      expect { target.persist_batch([], context: nil) }.to raise_error(
        DataPorter::Error, /model_name is required/
      )
    end
  end

  describe "default hooks" do
    let(:target) { target_class.new }
    let(:record) { DataPorter::StoreModels::ImportRecord.new }

    it "transform returns record unchanged" do
      expect(target.transform(record)).to be(record)
    end

    it "validate is a no-op" do
      expect { target.validate(record) }.not_to raise_error
    end

    it "persist raises NotImplementedError" do
      expect { target.persist(record, context: nil) }.to raise_error(NotImplementedError)
    end

    it "after_import is a no-op" do
      expect { target.after_import({}, context: nil) }.not_to raise_error
    end

    it "on_error is a no-op" do
      expect { target.on_error(record, StandardError.new, context: nil) }.not_to raise_error
    end
  end
end
