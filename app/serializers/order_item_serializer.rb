# frozen_string_literal: true

class OrderItemSerializer
  include JSONAPI::Serializer

  attributes :shop_product_id, :sku, :name, :unit_price_cents, :quantity
end
