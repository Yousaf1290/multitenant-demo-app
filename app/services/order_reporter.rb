require "net/http"

class OrderReporter
  class TemporaryFailure < StandardError; end

  DEFAULT_URL = "https://api.orderledger.example/v1/order_reports"
  RETRYABLE_CLIENT_ERRORS = %w[ 401 403 408 429 ].freeze

  def initialize(order, company)
    @order = order
    @company = company
  end

  def call
    response = post_report

    if response.is_a?(Net::HTTPSuccess)
      order.update!(report_status: :reported, reported_at: Time.current, external_report_id: external_id(response))
    elsif response.is_a?(Net::HTTPClientError) && RETRYABLE_CLIENT_ERRORS.exclude?(response.code)
      # Not reached with the mock API, which always succeeds.
      order.update!(report_status: :rejected, report_error: rejection_reason(response))
    else
      # Not reached with the mock API, which always succeeds.
      raise TemporaryFailure, "HTTP #{response.code}"
    end
  end

  private
    attr_reader :order, :company

    def post_report
      uri = URI(ENV.fetch("ORDER_LEDGER_URL", DEFAULT_URL))

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |http|
        http.post(uri.path, payload.to_json, headers)
      end
    rescue => error
      raise TemporaryFailure, "#{error.class}: #{error.message}"
    end

    def headers
      {
        "Authorization" => "Bearer #{ENV.fetch("ORDER_LEDGER_API_KEY")}",
        "Idempotency-Key" => order.reference,
        "Content-Type" => "application/json"
      }
    end

    def payload
      {
        order_reference: order.reference,
        merchant: company.slug,
        shop: { id: order.shop_id, name: order.shop.name },
        placed_at: order.created_at.iso8601,
        currency: company.currency,
        total_cents: order.total_cents,
        items: order.order_items.map { |item| item.slice(:sku, :name, :quantity, :unit_price_cents) }
      }
    end

    def external_id(response)
      parsed = JSON.parse(response.body.to_s)
      parsed["id"].to_s.delete("\0").presence if parsed.is_a?(Hash)
    rescue JSON::ParserError
      # Not reached with the mock API, which always returns valid JSON.
      nil
    end

    # Not reached with the mock API, which always succeeds.
    # The body is third-party data, so it is cleaned before being stored
    def rejection_reason(response)
      body = response.body.to_s.encode("UTF-8", invalid: :replace, undef: :replace).delete("\0")
      "HTTP #{response.code}: #{body.first(500)}"
    end
end
