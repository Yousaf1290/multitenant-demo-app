class ReconcileOrderReportsJob < ApplicationJob
  STALE_AFTER = 15.minutes

  def perform
    Company.find_each do |company|
      TenantRecord.with_company(company) do
        Order.report_pending.where(created_at: ...STALE_AFTER.ago).ids.each do |order_id|
          ReportOrderJob.perform_later(company.id, order_id)
        end
      end
    rescue ActiveRecord::ActiveRecordError => error
      logger.error "Could not reconcile #{company.slug}: #{error.message}"
    end
  end
end
