# frozen_string_literal: true

RSpec.describe DataPorter::ParseJob do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Guests"
      model_name "Guest"
      columns do
        column :name, type: :string
      end
    end
  end

  let(:data_import) do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:guests, target_class)
    DataPorter::DataImport.create!(
      target_key: "guests",
      source_type: "csv",
      user_type: "User",
      user_id: 1
    )
  end

  it "calls Orchestrator#parse!" do
    orchestrator = instance_double(DataPorter::Orchestrator, parse!: nil)
    allow(DataPorter::Orchestrator).to receive(:new).and_return(orchestrator)

    described_class.new.perform(data_import.id)

    expect(orchestrator).to have_received(:parse!)
  end

  it "uses the configured queue name" do
    job = described_class.new
    expect(job.queue_name).to eq("imports")
  end
end
