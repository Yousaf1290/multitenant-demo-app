class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :sku, null: false, index: { unique: true }
      t.string :name, null: false
      t.integer :price_cents, null: false

      t.timestamps

      t.check_constraint "price_cents >= 0", name: "products_price_not_negative"
    end
  end
end
