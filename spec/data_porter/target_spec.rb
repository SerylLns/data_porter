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
  end

  describe "deduplicate_by DSL" do
    it "emits a deprecation warning" do
      allow(DataPorter.deprecator).to receive(:warn)

      Class.new(described_class) { deduplicate_by :email }

      expect(DataPorter.deprecator).to have_received(:warn).with(/match_by/)
    end

    it "still stores dedup keys" do
      allow(DataPorter.deprecator).to receive(:warn)

      klass = Class.new(described_class) { deduplicate_by :email }

      expect(klass._dedup_keys).to eq([:email])
    end
  end

  describe "match_by DSL" do
    it "stores a single match key" do
      klass = Class.new(described_class) { match_by :email }

      expect(klass._match_keys).to eq([:email])
    end

    it "stores composite match keys as symbols" do
      klass = Class.new(described_class) { match_by "first_name", :last_name }

      expect(klass._match_keys).to eq(%i[first_name last_name])
    end

    it "is nil when not declared" do
      expect(target_class._match_keys).to be_nil
    end
  end

  describe "default existing_scope" do
    it "returns all records of the model" do
      klass = Class.new(described_class) { model_name "User" }

      expect(klass.new.existing_scope.to_sql).to eq(User.all.to_sql)
    end

    it "raises Error when model_name is not defined" do
      target = Class.new(described_class).new

      expect { target.existing_scope }.to raise_error(DataPorter::Error, /model_name is required/)
    end
  end

  describe "default diff_attributes" do
    it "returns the existing attributes matching declared columns" do
      klass = Class.new(described_class) do
        columns do
          column :email, type: :email
          column :nickname, type: :string
        end
      end
      existing = Contact.new(email: "alice@example.com", first_name: "Alice")

      expect(klass.new.diff_attributes(existing)).to eq("email" => "alice@example.com")
    end
  end

  describe "default update" do
    it "updates the existing record with the record attributes" do
      existing = User.create!
      allow(existing).to receive(:update!)
      record = DataPorter::StoreModels::ImportRecord.new(data: { "name" => "Alice" })

      target_class.new.update(record, existing, context: nil)

      expect(existing).to have_received(:update!).with(record.attributes)
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

    it "does not collide with a host-defined model_class method" do
      klass = Class.new(described_class) do
        model_name "Guest"
        bulk_mode
        define_method(:model_class) { Guest }
      end
      allow(model_class).to receive(:insert_all)

      klass.new.persist_batch([], context: nil)

      expect(model_class).to have_received(:insert_all)
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
