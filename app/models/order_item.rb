class OrderItem < TenantRecord
  belongs_to :order
  belongs_to :shop_product

  validates :quantity, numericality: { only_integer: true, in: 1..MAX_INTEGER }
  validate :sold_by_the_order_shop

  before_validation :copy_product_details, on: :create

  def line_total_cents
    unit_price_cents * quantity
  end

  private
    def copy_product_details
      return unless shop_product

      self.sku = shop_product.sku
      self.name = shop_product.name
      self.unit_price_cents = shop_product.price_cents
    end

    def sold_by_the_order_shop
      return unless shop_product && order

      errors.add(:shop_product, "is not sold by this shop") if shop_product.shop_id != order.shop_id
    end
end
