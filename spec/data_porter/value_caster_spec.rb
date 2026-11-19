# frozen_string_literal: true

RSpec.describe DataPorter::ValueCaster do
  let(:caster) do
    described_class.new(
      [
        DataPorter::DSL::Column.new(name: :external_id, type: :integer),
        DataPorter::DSL::Column.new(name: :score, type: :decimal),
        DataPorter::DSL::Column.new(name: :active, type: :boolean),
        DataPorter::DSL::Column.new(name: :born_on, type: :date),
        DataPorter::DSL::Column.new(name: :email, type: :email)
      ]
    )
  end

  it "casts integer columns" do
    expect(caster.call("external_id", "007")).to eq(7)
  end

  it "casts decimal columns" do
    expect(caster.call("score", "1.50")).to eq(BigDecimal("1.5"))
  end

  it "casts boolean columns" do
    expect(caster.call("active", "true")).to be(true)
  end

  it "casts date columns" do
    expect(caster.call("born_on", "2026-11-19")).to eq(Date.new(2026, 11, 19))
  end

  it "stringifies columns without a caster" do
    expect(caster.call("email", 42)).to eq("42")
  end

  it "returns nil for nil and empty values" do
    expect([caster.call("external_id", nil), caster.call("email", "")]).to eq([nil, nil])
  end

  it "accepts symbol field names" do
    expect(caster.call(:external_id, "7")).to eq(7)
  end
end
