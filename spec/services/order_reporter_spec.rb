require "rails_helper"

RSpec.describe OrderReporter do
  let(:url) { OrderReporter::DEFAULT_URL }
  let(:company) { companies(:alpha) }
  let(:order) { create_order(create_shop_product) }

  around { |example| TenantRecord.with_company(companies(:alpha)) { example.run } }

  it "sends the agreed payload and headers" do
    stub_request(:post, url).to_return(status: 201, body: { id: "ext-1" }.to_json)

    described_class.new(order, company).call

    expected = {
      order_reference: order.reference,
      merchant: "alpha",
      shop: { id: order.shop_id, name: "North" },
      placed_at: order.created_at.utc.iso8601,
      currency: "USD",
      total_cents: 3000,
      items: [ { sku: "TEE", name: "TEE name", quantity: 2, unit_price_cents: 1500 } ]
    }
    expect(a_request(:post, url).with(body: expected.to_json, headers: {
      "Authorization" => "Bearer test-key", "Idempotency-Key" => order.reference
    })).to have_been_made.once
  end

  it "marks the order reported on success and saves the external id" do
    stub_request(:post, url).to_return(status: 201, body: { id: "ext-1" }.to_json)

    described_class.new(order, company).call

    expect(order.reload).to be_report_reported
    expect(order.external_report_id).to eq("ext-1")
  end

  it "raises and keeps the order pending on a temporary failure" do
    stub_request(:post, url).to_return(status: 503)

    expect { described_class.new(order, company).call }.to raise_error(OrderReporter::TemporaryFailure)
    expect(order.reload).to be_report_pending
  end

  it "raises and keeps the order pending when the API cannot be reached" do
    stub_request(:post, url).to_timeout

    expect { described_class.new(order, company).call }.to raise_error(OrderReporter::TemporaryFailure)
    expect(order.reload).to be_report_pending
  end

  it "rejects the order on a client error and keeps the reason" do
    stub_request(:post, url).to_return(status: 422, body: "not acceptable")

    described_class.new(order, company).call

    expect(order.reload).to be_report_rejected
    expect(order.report_error).to eq("HTTP 422: not acceptable")
  end
end
