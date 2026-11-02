require "rails_helper"

RSpec.describe ReportOrderJob, type: :job do
  let(:url) { OrderReporter::DEFAULT_URL }
  let(:alpha) { companies(:alpha) }
  let(:beta) { companies(:beta) }
  let!(:order) { TenantRecord.with_company(alpha) { create_order(create_shop_product) } }

  def report_status
    TenantRecord.with_company(alpha) { order.reload.report_status }
  end

  it "reports a pending order" do
    stub_request(:post, url).to_return(status: 201, body: "{}")

    described_class.perform_now(alpha.id, order.id)

    expect(report_status).to eq("reported")
  end

  it "makes 5 attempts with one key, then stops and leaves the order pending" do
    stub_request(:post, url).to_return(status: 503)

    perform_enqueued_jobs { described_class.perform_later(alpha.id, order.id) }

    expect(a_request(:post, url).with(headers: { "Idempotency-Key" => order.reference })).to have_been_made.times(5)
    expect(report_status).to eq("pending")
  end

  it "stops retrying once the API recovers" do
    stub_request(:post, url).to_return({ status: 503 }, { status: 201, body: "{}" })

    perform_enqueued_jobs { described_class.perform_later(alpha.id, order.id) }

    expect(a_request(:post, url)).to have_been_made.twice
    expect(report_status).to eq("reported")
  end

  it "does not resend an order that is no longer pending" do
    TenantRecord.with_company(alpha) { order.update!(report_status: :reported) }

    described_class.perform_now(alpha.id, order.id)

    expect(a_request(:post, url)).not_to have_been_made
  end

  it "reads the right company when two companies share an order id" do
    stub_request(:post, url).to_return(status: 201, body: "{}")
    TenantRecord.with_company(beta) { create_order(create_shop_product(sku: "BETA"), id: order.id) }

    described_class.perform_now(beta.id, order.id)

    expect(a_request(:post, url).with { |request| JSON.parse(request.body)["merchant"] == "beta" }).to have_been_made.once
    expect(report_status).to eq("pending")
  end
end
