require "rails_helper"

RSpec.describe ReconcileOrderReportsJob, type: :job do
  let(:alpha) { companies(:alpha) }
  let(:beta) { companies(:beta) }

  def old_order(sku:)
    create_order(create_shop_product(sku: sku), created_at: 16.minutes.ago)
  end

  it "re-queues pending orders older than 15 minutes, in every company" do
    stale = TenantRecord.with_company(alpha) { old_order(sku: "ALPHA") }
    other = TenantRecord.with_company(beta) { old_order(sku: "BETA") }

    described_class.perform_now

    expect(ReportOrderJob).to have_been_enqueued.with(alpha.id, stale.id)
    expect(ReportOrderJob).to have_been_enqueued.with(beta.id, other.id)
  end

  it "leaves recent and finished orders alone" do
    TenantRecord.with_company(alpha) do
      create_order(create_shop_product(sku: "RECENT"))
      old_order(sku: "DONE").update!(report_status: :reported)
      old_order(sku: "REFUSED").update!(report_status: :rejected)
    end

    described_class.perform_now

    expect(ReportOrderJob).not_to have_been_enqueued
  end
end
