class Company < ApplicationRecord
  enum :status, { active: "active", suspended: "suspended" }

  attr_readonly :slug, :database_name

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, length: { maximum: 20 }, format: { with: /\A[a-z0-9_]+\z/ }
  validates :database_name, presence: true, uniqueness: true

  before_validation(on: :create) { self.database_name ||= "multitenant_demo_app_#{Rails.env}_tenant_#{slug}" }

  def shard
    slug.to_sym
  end
end
