class Shop < TenantRecord
  has_many :shop_products
  has_many :orders

  validates :name, presence: true
end
