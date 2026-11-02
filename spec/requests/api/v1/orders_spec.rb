require "rails_helper"

RSpec.describe "Orders", type: :request do
  let(:alpha) { companies(:alpha) }

  before do
    TenantRecord.with_company(alpha) do
      @shop = Shop.create!(name: "North")
      @tee = create_shop_product(shop: @shop)
      @own = @shop.shop_products.create!(sku: "BAG", name: "Bag", price_cents: 500)
      @headers = bearer(AuthToken.issue(create_user, alpha))
    end
  end

  def place(items, **order_attributes)
    post "/api/v1/shops/#{@shop.id}/orders", params: { order: { items: items, **order_attributes } }, headers: @headers, as: :json
  end

  def order_count
    TenantRecord.with_company(alpha) { Order.count }
  end

  it "totals the order, returns it and queues the report" do
    place [ { shop_product_id: @tee.id, quantity: 2 }, { shop_product_id: @own.id, quantity: 3 } ]

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("data", "attributes")).to include("total_cents" => 4500, "report_status" => "pending")
    expect(ReportOrderJob).to have_been_enqueued.with(alpha.id, response.parsed_body.dig("data", "id").to_i)
  end

  it "ignores a price or total sent by the client" do
    place [ { shop_product_id: @own.id, quantity: 1, unit_price_cents: 1 } ], total_cents: 1

    expect(response.parsed_body.dig("data", "attributes", "total_cents")).to eq(500)
  end

  it "refuses another shop's product and saves nothing" do
    foreign = TenantRecord.with_company(alpha) { create_shop_product(sku: "OTHER", shop: Shop.create!(name: "South")) }

    expect { place [ { shop_product_id: foreign.id, quantity: 1 } ] }.not_to change { order_count }
    expect(response).to have_http_status(:not_found)
  end

  it "returns a 422 naming the field for an invalid quantity, and saves nothing" do
    expect { place [ { shop_product_id: @own.id, quantity: 0 } ] }.not_to change { order_count }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["errors"].first).to include("status" => 422, "title" => "order_items.quantity")
  end

  it "still returns 201 when the queue is down, because the order is saved" do
    allow(ReportOrderJob).to receive(:perform_later).and_raise(SolidQueue::Job::EnqueueError, "queue down")

    place [ { shop_product_id: @own.id, quantity: 1 } ]

    expect(response).to have_http_status(:created)
  end

  it "reads an order back only under its own shop" do
    order = TenantRecord.with_company(alpha) { create_order(@tee) }
    other_shop = TenantRecord.with_company(alpha) { Shop.create!(name: "South") }

    get "/api/v1/shops/#{@shop.id}/orders/#{order.id}", headers: @headers
    expect(response.parsed_body.dig("data", "attributes", "reference")).to eq(order.reference)

    get "/api/v1/shops/#{other_shop.id}/orders/#{order.id}", headers: @headers
    expect(response).to have_http_status(:not_found)
  end
end
