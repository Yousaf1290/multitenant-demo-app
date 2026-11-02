class CreateShopProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :shop_products do |t|
      t.references :shop, null: false, foreign_key: true, index: false
      t.references :product, foreign_key: true
      t.string :sku
      t.string :name
      t.integer :price_cents

      t.timestamps

      t.index [ :shop_id, :product_id ], unique: true
      t.index [ :shop_id, :sku ], unique: true
      t.check_constraint "price_cents >= 0", name: "shop_products_price_not_negative"
      t.check_constraint <<~SQL.squish, name: "shop_products_linked_or_own"
        (product_id IS NOT NULL AND sku IS NULL AND name IS NULL)
        OR (product_id IS NULL AND sku IS NOT NULL AND name IS NOT NULL AND price_cents IS NOT NULL)
      SQL
    end
  end
end
