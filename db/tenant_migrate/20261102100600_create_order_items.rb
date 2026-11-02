class CreateOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :shop_product, null: false, foreign_key: true
      t.string :sku, null: false
      t.string :name, null: false
      t.integer :unit_price_cents, null: false
      t.integer :quantity, null: false

      t.timestamps

      t.check_constraint "unit_price_cents >= 0", name: "order_items_price_not_negative"
      t.check_constraint "quantity > 0", name: "order_items_quantity_positive"
    end
  end
end
