# frozen_string_literal: true

class ProductSerializer
  include JSONAPI::Serializer

  attributes :sku, :name, :price_cents
end
