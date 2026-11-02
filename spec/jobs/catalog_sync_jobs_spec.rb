require "rails_helper"

RSpec.describe "Catalog sync jobs", type: :job do
  let(:alpha) { companies(:alpha) }
  let(:beta) { companies(:beta) }

  it "syncs only its own company, even when both have the same sku" do
    TenantRecord.with_company(beta) { Product.create!(sku: "TEE", name: "Beta Tee", price_cents: 5000) }

    with_csv("sku,name,price_cents\nTEE,Alpha Tee,2000\n") do |path|
      alpha.update!(catalog_csv_path: path)
      SyncCatalogJob.perform_now(alpha.id)
    end

    expect(TenantRecord.with_company(alpha) { Product.where(sku: "TEE").pick(:price_cents) }).to eq(2000)
    expect(TenantRecord.with_company(beta) { Product.where(sku: "TEE").pick(:price_cents) }).to eq(5000)
  end

  it "schedules only active companies with a feed" do
    alpha.update!(catalog_csv_path: "data/catalogs/alpha.csv")
    Company.create!(name: "Off", slug: "off", status: "suspended", catalog_csv_path: "data/catalogs/off.csv")

    ScheduleCatalogSyncsJob.perform_now

    expect(SyncCatalogJob).to have_been_enqueued.exactly(:once)
    expect(SyncCatalogJob).to have_been_enqueued.with(alpha.id)
  end
end
