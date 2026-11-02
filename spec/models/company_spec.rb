require "rails_helper"

RSpec.describe Company, type: :model do
  it "names its database after its slug" do
    company = described_class.create!(name: "Initech", slug: "initech")

    expect(company.database_name).to eq("multitenant_demo_app_test_tenant_initech")
  end

  it "rejects slugs that are unsafe or too long for a database name" do
    [ "Alpha", "al-pha", "alpha;drop", "a" * 21 ].each do |slug|
      expect(described_class.new(name: "Bad", slug: slug)).not_to be_valid
    end
  end

  it "cannot change its slug after creation" do
    expect { companies(:alpha).update!(slug: "renamed") }.to raise_error(ActiveRecord::ReadonlyAttributeError)
  end
end
