class Product < TenantRecord
  has_many :shop_products

  validates :sku, presence: true, uniqueness: true
  validates :name, presence: true
  validates :price_cents, numericality: { only_integer: true, in: 0..MAX_INTEGER }
end
