# frozen_string_literal: true

class OrderSerializer
  include JSONAPI::Serializer

  attributes :reference, :total_cents, :report_status, :reported_at, :created_at

  has_many :order_items
end
