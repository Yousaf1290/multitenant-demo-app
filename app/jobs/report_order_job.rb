# Calls the third-party API, through OrderReporter, to report an order.
class ReportOrderJob < ApplicationJob
  include TenantJob

  # With the mock API, retries only happen if the server is down, because it always succeeds.
  retry_on OrderReporter::TemporaryFailure, wait: :polynomially_longer, attempts: 5 do |job, error|
    job.logger.warn "Order #{job.arguments.last} still not reported: #{error.message}"
  end

  def perform(_company_id, order_id)
    order = Order.find(order_id)

    OrderReporter.new(order, company).call if order.report_pending?
  end
end
