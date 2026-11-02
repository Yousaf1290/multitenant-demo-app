class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.uuid :reference, null: false, default: -> { "gen_random_uuid()" }, index: { unique: true }
      t.references :shop, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.bigint :total_cents, null: false
      t.string :report_status, null: false, default: "pending"
      t.datetime :reported_at
      t.string :external_report_id
      t.text :report_error

      t.timestamps

      t.index :created_at, where: "report_status = 'pending'", name: "index_orders_awaiting_report"
      t.check_constraint "total_cents >= 0", name: "orders_total_not_negative"
    end
  end
end
