namespace :tenants do
  desc "Create any missing company databases and migrate them all; safe to re-run"
  task provision: :environment do
    Company.find_each do |company|
      puts "== #{company.slug}"
      TenantRecord.provision(company)
    end
  end

  desc "Run pending migrations on every existing company database"
  task migrate: :environment do
    Company.find_each do |company|
      puts "== #{company.slug}"
      TenantRecord.migrate(company)
    end
  end
end
