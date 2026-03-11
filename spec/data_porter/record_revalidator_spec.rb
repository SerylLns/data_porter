# frozen_string_literal: true

RSpec.describe DataPorter::RecordRevalidator do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"

      columns do
        column :name, type: :string, required: true
        column :email, type: :string, required: true, transform: %i[strip downcase]
        column :age, type: :integer
      end
    end
  end

  let(:target) { target_class.new }
  let(:revalidator) { described_class.new(target) }

  describe "#call" do
    context "when record data is valid" do
      let(:record) do
        DataPorter::StoreModels::ImportRecord.new(
          line_number: 1,
          status: "missing",
          data: { "name" => "Alice", "email" => " ALICE@TEST.COM ", "age" => "30" },
          errors_list: [DataPorter::StoreModels::Error.new(message: "stale error")]
        )
      end

      it "clears previous errors" do
        revalidator.call(record)
        expect(record.errors_list).to be_empty
      end

      it "applies transforms" do
        revalidator.call(record)
        expect(record.data["email"]).to eq("alice@test.com")
      end

      it "sets status to complete" do
        revalidator.call(record)
        expect(record.status).to eq("complete")
      end

      it "returns the record" do
        expect(revalidator.call(record)).to eq(record)
      end
    end

    context "when record has a missing required field" do
      let(:record) do
        DataPorter::StoreModels::ImportRecord.new(
          line_number: 2,
          status: "complete",
          data: { "name" => "", "email" => "bob@test.com", "age" => "25" }
        )
      end

      it "adds validation errors" do
        revalidator.call(record)
        messages = record.errors_list.map(&:message)
        expect(messages).to include("Name is required")
      end

      it "sets status to missing" do
        revalidator.call(record)
        expect(record.status).to eq("missing")
      end
    end

    context "when record has an invalid type" do
      let(:record) do
        DataPorter::StoreModels::ImportRecord.new(
          line_number: 3,
          status: "complete",
          data: { "name" => "Charlie", "email" => "charlie@test.com", "age" => "not_a_number" }
        )
      end

      it "adds type validation error" do
        revalidator.call(record)
        messages = record.errors_list.map(&:message)
        expect(messages).to include("Age: invalid integer")
      end

      it "sets status to partial" do
        revalidator.call(record)
        expect(record.status).to eq("partial")
      end
    end

    context "with custom target validation" do
      let(:validating_target_class) do
        Class.new(DataPorter::Target) do
          label "ValidatedGuests"
          model_name "ValidatedGuest"

          columns do
            column :name, type: :string, required: true
          end

          def validate(record)
            record.add_error("Name too short") if record.data["name"].to_s.length < 3
          end
        end
      end

      let(:validating_target) { validating_target_class.new }
      let(:validating_revalidator) { described_class.new(validating_target) }

      let(:record) do
        DataPorter::StoreModels::ImportRecord.new(
          line_number: 1,
          status: "complete",
          data: { "name" => "AB" }
        )
      end

      it "runs custom target validation" do
        validating_revalidator.call(record)
        messages = record.errors_list.map(&:message)
        expect(messages).to include("Name too short")
      end
    end

    context "with custom target transform" do
      let(:transforming_target_class) do
        Class.new(DataPorter::Target) do
          label "TransformedGuests"
          model_name "TransformedGuest"

          columns do
            column :name, type: :string, required: true
          end

          def transform(record)
            record.data["name"] = record.data["name"].to_s.strip.capitalize
            record
          end
        end
      end

      let(:transforming_target) { transforming_target_class.new }
      let(:transforming_revalidator) { described_class.new(transforming_target) }

      let(:record) do
        DataPorter::StoreModels::ImportRecord.new(
          line_number: 1,
          status: "missing",
          data: { "name" => "  alice  " }
        )
      end

      it "applies target transform" do
        transforming_revalidator.call(record)
        expect(record.data["name"]).to eq("Alice")
      end
    end

    context "idempotency" do
      let(:record) do
        DataPorter::StoreModels::ImportRecord.new(
          line_number: 1,
          data: { "name" => "Alice", "email" => " ALICE@TEST.COM ", "age" => "30" }
        )
      end

      it "produces same result when called twice" do
        revalidator.call(record)
        first_status = record.status
        first_data = record.data.dup

        revalidator.call(record)
        expect(record.status).to eq(first_status)
        expect(record.data).to eq(first_data)
      end
    end
  end
end
