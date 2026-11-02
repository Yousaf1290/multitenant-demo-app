# frozen_string_literal: true

class ShopProductSerializer
  include JSONAPI::Serializer

  attributes :product_id, :sku, :name, :price_cents
end
