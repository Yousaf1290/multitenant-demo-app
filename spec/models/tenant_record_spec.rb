require "rails_helper"

RSpec.describe TenantRecord, type: :model do
  let(:alpha) { companies(:alpha) }
  let(:beta) { companies(:beta) }

  it "keeps each company's data in its own database" do
    described_class.with_company(alpha) { Product.create!(sku: "ANVIL", name: "Anvil", price_cents: 9900) }

    expect(described_class.with_company(alpha) { Product.pluck(:sku) }).to eq([ "ANVIL" ])
    expect(described_class.with_company(beta) { Product.pluck(:sku) }).to be_empty
  end

  it "raises when a tenant model is used with no company selected" do
    expect { Product.count }.to raise_error(ActiveRecord::ConnectionNotDefined)
  end

  it "raises when switching company inside a tenant block" do
    expect {
      described_class.with_company(alpha) { described_class.with_company(beta) { Product.count } }
    }.to raise_error(ArgumentError)
  end

  it "keeps host models on the host database inside a tenant block" do
    described_class.with_company(alpha) do
      expect(Product.connection_db_config.database).to eq("multitenant_demo_app_test_tenant_alpha")
      expect(Company.connection_db_config.database).to eq("multitenant_demo_app_test")
    end
  end

  describe ".provision" do
    self.use_transactional_tests = false

    let(:company) { Company.new(slug: "scratch", database_name: "multitenant_demo_app_test_tenant_scratch") }

    after { ActiveRecord::Base.with_connection { |connection| connection.drop_database(company.database_name) } }

    it "creates the database, is safe to repeat, and leaves the app on the host database" do
      2.times { described_class.provision(company) }

      expect(Company.connection_db_config.database).to eq("multitenant_demo_app_test")
      databases = ActiveRecord::Base.with_connection { |connection| connection.select_values("SELECT datname FROM pg_database") }
      expect(databases).to include(company.database_name)
    end
  end
end
