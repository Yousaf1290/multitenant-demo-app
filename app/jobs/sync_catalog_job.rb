class SyncCatalogJob < ApplicationJob
  include TenantJob

  limits_concurrency key: ->(company_id) { company_id }, on_conflict: :discard

  def perform(_company_id)
    CatalogImport.new(Rails.root.join(company.catalog_csv_path)).call
  end
end
