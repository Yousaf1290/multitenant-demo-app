class Order < TenantRecord
  belongs_to :shop
  belongs_to :user
  has_many :order_items

  enum :report_status, { pending: "pending", reported: "reported", rejected: "rejected" }, prefix: :report

  validates :order_items, presence: true, on: :create

  before_create { self.total_cents = order_items.sum(&:line_total_cents) }
end
