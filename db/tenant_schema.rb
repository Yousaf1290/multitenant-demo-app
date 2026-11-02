# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_02_100600) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "shop_product_id", null: false
    t.string "sku", null: false
    t.string "name", null: false
    t.integer "unit_price_cents", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["shop_product_id"], name: "index_order_items_on_shop_product_id"
    t.check_constraint "quantity > 0", name: "order_items_quantity_positive"
    t.check_constraint "unit_price_cents >= 0", name: "order_items_price_not_negative"
  end

  create_table "orders", force: :cascade do |t|
    t.uuid "reference", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "shop_id", null: false
    t.bigint "user_id", null: false
    t.bigint "total_cents", null: false
    t.string "report_status", default: "pending", null: false
    t.datetime "reported_at"
    t.string "external_report_id"
    t.text "report_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_orders_awaiting_report", where: "((report_status)::text = 'pending'::text)"
    t.index ["reference"], name: "index_orders_on_reference", unique: true
    t.index ["shop_id"], name: "index_orders_on_shop_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
    t.check_constraint "total_cents >= 0", name: "orders_total_not_negative"
  end

  create_table "products", force: :cascade do |t|
    t.string "sku", null: false
    t.string "name", null: false
    t.integer "price_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.check_constraint "price_cents >= 0", name: "products_price_not_negative"
  end

  create_table "shop_products", force: :cascade do |t|
    t.bigint "shop_id", null: false
    t.bigint "product_id"
    t.string "sku"
    t.string "name"
    t.integer "price_cents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_shop_products_on_product_id"
    t.index ["shop_id", "product_id"], name: "index_shop_products_on_shop_id_and_product_id", unique: true
    t.index ["shop_id", "sku"], name: "index_shop_products_on_shop_id_and_sku", unique: true
    t.check_constraint "price_cents >= 0", name: "shop_products_price_not_negative"
    t.check_constraint "product_id IS NOT NULL AND sku IS NULL AND name IS NULL OR product_id IS NULL AND sku IS NOT NULL AND name IS NOT NULL AND price_cents IS NOT NULL", name: "shop_products_linked_or_own"
  end

  create_table "shops", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "shop_products"
  add_foreign_key "orders", "shops"
  add_foreign_key "orders", "users"
  add_foreign_key "shop_products", "products"
  add_foreign_key "shop_products", "shops"
end
