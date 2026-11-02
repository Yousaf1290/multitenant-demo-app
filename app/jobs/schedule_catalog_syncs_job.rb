class ScheduleCatalogSyncsJob < ApplicationJob
  def perform
    Company.active.where.not(catalog_csv_path: nil).find_each do |company|
      SyncCatalogJob.perform_later(company.id)
    end
  end
end
