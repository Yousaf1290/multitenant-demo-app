class ShopProduct < TenantRecord
  belongs_to :shop
  belongs_to :product, optional: true
  has_many :order_items

  validates :sku, :name, :price_cents, presence: true
  validates :sku, uniqueness: { scope: :shop_id }
  validates :product_id, uniqueness: { scope: :shop_id }, allow_nil: true
  validates :price_cents, numericality: { only_integer: true, in: 0..MAX_INTEGER }, allow_nil: true

  def sku
    super || product&.sku
  end

  def name
    super || product&.name
  end

  def price_cents
    super || product&.price_cents
  end
end
