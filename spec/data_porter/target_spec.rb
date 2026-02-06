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
