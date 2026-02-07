# frozen_string_literal: true

RSpec.describe DataPorter::ExtractHeadersJob do
  let(:target_class) do
    Class.new(DataPorter::Target) do
      label "Test"
      model_name "Test"
    end
  end

  before do
    DataPorter::Registry.clear
    DataPorter::Registry.register(:test, target_class)
  end

  it "inherits from ActiveJob::Base" do
    expect(described_class.superclass).to eq(ActiveJob::Base)
  end

  it "calls Orchestrator#extract_headers!" do
    import = DataPorter::DataImport.create!(
      target_key: "test",
      source_type: "csv"
    )
    orchestrator = instance_double(DataPorter::Orchestrator)
    allow(DataPorter::Orchestrator).to receive(:new).and_return(orchestrator)
    allow(orchestrator).to receive(:extract_headers!)

    described_class.perform_now(import.id)

    expect(orchestrator).to have_received(:extract_headers!)
  end
end
